# Recipe: a shop - members who sign in, who may do what, an order's lifecycle, prices kept and summed

A complete model for "members, products and orders": sign-up, sign-in and sign-out, data a member
sees only of their own, a role only an administrator sets, an address and a card as values, an
order that is placed, shipped or cancelled (409 when its state does not allow it), the price kept as
it was when ordered, totals the server works out, a reference to a product that must exist (404), an
administrator's report, a log line per shipped or cancelled order, and the data a new installation
starts with. Start from `new-project.md` (build files, wrapper) and use these files instead of its
`shop` ones. The agent kit's contract test generates, builds, starts and calls exactly this project,
with every request shown at the end.

**It needs ElastiCORE 3.0.261021 or later** (the generated sign-in, the 409 for a refused step, the
404 for a missing reference). It works as written with `architecture = 'hexagonal'`. Rename `store`
and `com.acme.store` together if the task needs another name.

## `src/main/resources/blueprint/store/env.yml`

```yaml
elasticore:
  enable: true
  config:
    domainName: store
    framework: springboot
    mode: jpa
    j2ee: jakarta
    apiPath: "/api"
  namespace:
    base: com.acme.store
```

## `src/main/resources/blueprint/store/model/enum.yml`

```yaml
enumeration:
  MemberRole:
    meta: enum @db(code) @json(code) -- member role
    fields:
      code:  string(1) @code
      label: string(20)
    enum:
      USER:  U, User
      ADMIN: A, Administrator

  OrderStatus:
    meta: enum @db(code) @json(code) -- order status
    fields:
      code:  string(3) @code
      label: string(20)
    enum:
      PLACED:    PLC, Placed
      SHIPPED:   SHP, Shipped
      CANCELLED: CAN, Cancelled

  CardType:
    meta: enum @db(code) @json(code) -- card type
    fields:
      code:  string(4) @code
      label: string(20)
    enum:
      VISA:        VISA, Visa
      MASTER_CARD: MAST, Master Card
```

## `src/main/resources/blueprint/store/model/entity.yml`

```yaml
entity:
  Address:
    meta: entity @embeddable -- address
    fields:
      street:  string(100)! @notblank -- street
      city:    string(50)! @notblank -- city
      zipcode: string(10)! @pattern('^[0-9]{5}(-[0-9]{4})?$', 'zipcode must be 12345 or 12345-6789') -- zip code

  Card:
    meta: entity @embeddable -- payment card
    fields:
      cardNumber: string(30)! @writeonly -- card number, accepted and never answered
      cardType:   CardType! -- card type
      expiry:     string(5)! @pattern('^(0[1-9]|1[0-2])/[0-9]{2}$', 'expiry must be MM/YY') -- expiry, MM/YY

  Member:
    meta: entity @root @editable @expose(20) @signin @owner(memberId) @access(read=owner, create=public, update=owner)
          @Index(name="uk_member_login", columnList="login", unique=true) -- member
    fields:
      memberId:  long @id @sequence
      login:     string(20)! @login @search(eq) -- login id
      password:  string(255)! @password @length(min=8) -- password of 8 characters or more, kept as a hash and never answered
      name:      string(50)! @notblank -- name
      email:     string(100) @email -- e-mail address
      birthDate: date @past -- date of birth, in the past
      role:      MemberRole @default(MemberRole.USER) @access(admin) -- role, set by an administrator only
      address:   Address! @Embedded -- home address

  Product:
    meta: entity @root @editable @expose(20) @access(read=public) @sort(name+) -- product
    fields:
      productId: long @id @sequence
      name:      string(50)! @notblank @search(like) -- name
      price:     money(10.2)! @min(0.01, 'price must be positive') -- price

  PurchaseOrder:
    meta: entity @root @expose(20) @owner(memberId) @access(read=owner, create=user, cancel=owner)
          @event(Shipped(total), Cancelled(total)) @sort(orderId-) -- order
    fields:
      orderId:   long @id @sequence
      memberId:  long -- who ordered it, the signed-in member set by the server
      status:    OrderStatus -- status
      orderedAt: datetime @readonly @default(now) -- ordered at, set by the server
      shipTo:    Address @Embedded -- delivery address
      card:      Card! @Embedded -- payment card
      total:     money(12.2) @compute(sum(lines.subTotal)) -- the lines added up
      lines:     List<OrderLine> @OneToMany(mappedBy="order") @dtype(List<OrderLineDTO>) @minsize(1, 'an order needs a line')
    states:
      status:
        initial: PLACED
        ship:    PLACED -> SHIPPED
        cancel:  PLACED -> CANCELLED
        delete:  CANCELLED

  OrderLine:
    meta: entity -- order line
    fields:
      lineId:    long @id @sequence
      order:     PurchaseOrder @ManyToOne
      product:   Product! @ManyToOne -- the product ordered
      quantity:  quantity! @min(1) -- quantity
      unitPrice: money(10.2) @snapshot(product.price) -- the price when ordered, kept
      subTotal:  money(12.2) @compute(unitPrice * quantity) -- unit price x quantity

dto:
  OrderLineDTO:
    meta: dto @template(OrderLine)
```

Why each piece is there:

- **Sign-in is generated.** `@signin` on the line of the entity with `@login` and `@password` gives
  its controller `POST /api/store/member/signin` (`{"login": "...", "password": "..."}`; 401 `Wrong
  login or password`), `POST /api/store/member/signout` (204) and `GET /api/store/member/me` (401 for
  a visitor), and the TypeScript client `signIn`, `signOut` and `me()`. The session keeps the member's
  key and its `role`, which `@access` reads (`ADMIN` is the administrator) - because `role` is
  `@access(admin)`: a role field a member could write is not put in the session (a DSL warning says
  so). One entity of the application says `@signin`. Do not write a sign-in controller; a sign-in
  rule of your own (a locked account) goes in `MemberService` as an override of
  `authenticate(login, password)`, which the generated `signin` calls.
- `@password` stores a hash and never answers it; `@length(min=8)` is checked on the password sent, before it is hashed. `role ... @access(admin)`: a member who signs up
  with `"role": "A"` is stored as `U` - only an administrator sets it.
- `@access(read=owner, create=public, update=owner)` with `@owner(memberId)`: anyone signs up, a member
  reads and changes only their own record (another's answers 404), and what the line does not name
  (`delete`) is the administrator's. On `PurchaseOrder`, `create=user` makes the signed-in member the
  owner whatever the request says, and `cancel=owner` lets them cancel their own; `ship` and `delete`
  are the administrator's. A visitor gets 401, a member who may not 403.
- `Address` and `Card` are values (`@embeddable`), used by more than one entity with `@Embedded`;
  their `!` fields are required when the value is sent, and `Address!` makes the whole value required.
  `@writeonly` takes the card number and never answers it. `@pattern` answers 400 with its message.
  `@past` refuses a date of birth in the future.
- `states:` is the order's lifecycle: `ship` only from `PLACED`, `cancel` only from `PLACED`, and a
  row is deleted only when `CANCELLED`. Anything else answers 409 with `code`
  `state.PurchaseOrder.status.ship` (or `.cancel`, `.delete`). The controller gets
  `POST /api/store/purchaseOrder/{orderId}/ship` and `.../cancel`; the TypeScript client `canShip(order)`
  for the buttons. An order has no `PUT`: it changes by its commands only.
- `@snapshot(product.price)` copies the price once, when the line is saved: a later price change
  leaves the order as it was. `@compute(...)` works the subtotal and the total out on every save;
  values sent for them are ignored. A `productId` that names no product answers 404
  `Product 99 does not exist` (`code` `reference.OrderLine.product`) - generated, do not look it up.
- `@minsize(1, ...)` refuses an order without lines, sent as `[]` or left out: 400.
- `orderedAt: datetime @readonly @default(now)` is the time the order is made: the entity's initial
  value, never taken from a request, kept on every later save - no `beforeSave` for it.
  `@event(Shipped(total), Cancelled(total))`: the `ship` and `cancel` steps publish
  `PurchaseOrderShippedEvent` and `PurchaseOrderCancelledEvent` (`domain.event`) when the order is saved.

## `src/main/java/com/acme/store/StoreApplication.java`

```java
package com.acme.store;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class StoreApplication {
    public static void main(String[] args) {
        SpringApplication.run(StoreApplication.class, args);
    }
}
```

## `src/main/java/com/acme/store/StoreSeed.java`

```java
package com.acme.store;

import com.acme.store.application.MemberService;
import com.acme.store.application.ProductService;
import com.acme.store.application.dto.MemberDTO;
import com.acme.store.application.dto.MemberSrchDTO;
import com.acme.store.application.dto.ProductDTO;
import com.acme.store.domain.model.Address;
import com.acme.store.domain.model.MemberRole;
import io.elasticore.springboot3.domain.Money;
import io.elasticore.springboot3.security.CurrentUser;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
class StoreSeed implements ApplicationRunner {

    private final MemberService members;
    private final ProductService products;

    StoreSeed(MemberService members, ProductService products) {
        this.members = members;
        this.products = products;
    }

    @Override
    public void run(ApplicationArguments args) {
        CurrentUser.runAsSystem(() -> {
            MemberSrchDTO admin = new MemberSrchDTO();
            admin.setLogin("admin");
            if (members.countBySearch(admin) > 0) return;

            MemberDTO a = new MemberDTO();
            a.setLogin("admin");
            a.setPassword("admin-1234");
            a.setName("Administrator");
            a.setRole(MemberRole.ADMIN);
            a.setAddress(new Address("1 Main Street", "Seoul", "04524"));
            members.save(a);

            product("Angelfish", "10.00");
            product("Bulldog", "180.00");
        });
    }

    private void product(String name, String price) {
        ProductDTO p = new ProductDTO();
        p.setName(name);
        p.setPrice(Money.of(price));
        products.save(p);
    }
}
```

What a new installation starts with: an administrator and two products, saved through the
generated services so the password is hashed as any other. `CurrentUser.runAsSystem` says it is
the application itself writing - every `@access` check passes inside it, nowhere else.

## `src/main/java/com/acme/store/application/OrderEvents.java`

```java
package com.acme.store.application;

import com.acme.store.domain.event.PurchaseOrderCancelledEvent;
import com.acme.store.domain.event.PurchaseOrderShippedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/** A log line per shipped or cancelled order: the events the lifecycle publishes. */
@Component
class OrderEvents {

    private static final Logger log = LoggerFactory.getLogger(OrderEvents.class);

    @EventListener
    void shipped(PurchaseOrderShippedEvent e) {
        log.info("order {} SHIPPED total={}", e.getOrderId(), e.getTotal());
    }

    @EventListener
    void cancelled(PurchaseOrderCancelledEvent e) {
        log.info("order {} CANCELLED total={}", e.getOrderId(), e.getTotal());
    }
}
```

## Generate, then add the report

Run `./gradlew compileJava` once. It writes `src/main/java/com/acme/store/application/PurchaseOrderService.java`,
yours (a line at its top starts with `// Initially generated by ElastiCORE;` - the second, below
`//ecd:`, before 3.0.261030-rc5; the first from it). Add the method below
inside the class, before its last `}`, with your file-editing tool:

## Add to `PurchaseOrderService.java`

```java
    /**
     * Orders per status and the revenue of those not cancelled. "report" is not in the entity's
     * @access, so it is the administrator's: 401 for a visitor, 403 for a member. To let every
     * member call it, add report=user to @access.
     */
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public java.util.Map<String, Object> report() {
        ACCESS.require(currentUser, "report");
        java.util.Map<String, Long> counts = new java.util.LinkedHashMap<>();
        java.math.BigDecimal revenue = java.math.BigDecimal.ZERO;
        for (Object[] row : entityManager.createQuery(
                "select o.status, count(o), coalesce(sum(o.total), 0) from PurchaseOrder o group by o.status",
                Object[].class).getResultList()) {
            com.acme.store.domain.model.OrderStatus status = (com.acme.store.domain.model.OrderStatus) row[0];
            counts.put(status.name(), (Long) row[1]);
            if (status != com.acme.store.domain.model.OrderStatus.CANCELLED) {
                revenue = revenue.add(new java.math.BigDecimal(String.valueOf(row[2])));
            }
        }
        java.util.Map<String, Object> report = new java.util.LinkedHashMap<>();
        report.put("countByStatus", counts);
        report.put("revenue", revenue.setScale(2, java.math.RoundingMode.HALF_UP));
        return report;
    }
```

`ACCESS` (the entity's `@access`) and `currentUser` (who is asking) are fields of the generated
service, as `entityManager` is. Then the one controller of your own that calls it - a new file, no
ElastiCORE header, in the package of the generated controllers so the generated error handler
answers its 401 and 403:

## `src/main/java/com/acme/store/adapter/in/web/OrderReportController.java`

```java
package com.acme.store.adapter.in.web;

import com.acme.store.application.PurchaseOrderService;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** The administrator's report - the one operation the generated API does not have. */
@RestController
@RequestMapping("/api/store/purchaseOrder")
public class OrderReportController {

    private final PurchaseOrderService service;

    public OrderReportController(PurchaseOrderService service) {
        this.service = service;
    }

    @GetMapping("/report")
    public Map<String, Object> report() {
        return service.report();
    }
}
```

Build again (`./gradlew bootJar`): the generator reports `PurchaseOrderService.java`
`SKIP(user-owned)` - from 3.0.261030-rc5 `UNCHANGED(your edits kept)` - and keeps the method. Do not
write the services before the first generation.

## The API it generates, and the operation added

Base paths `/api/store/member`, `/api/store/product` and `/api/store/purchaseOrder`. Sign-in is a
session: keep the cookie (`curl -c jar -b jar`). Dates are `yyyy-MM-dd`, times
`yyyy-MM-dd HH:mm:ss`. A refusal is a problem body with `status`, `code` and `detail`; a 400 also has
`fieldErrors`. The seed signs in as `admin` / `admin-1234`.

| Operation | Request | Answer |
|---|---|---|
| Sign up | `POST /api/store/member` `{"login":"kim","password":"pw-12345","name":"Kim","address":{"street":"1 A St","city":"Seoul","zipcode":"12345"}}` | 200, the member: `role` `U`, no `password`; `"role":"A"` in the request is ignored |
| A taken login | the same `login` again | 409, `code` `unique` |
| Invalid member | `birthDate` tomorrow; `zipcode` `abc`; no `address`; a `password` of 7 characters | 400 each |
| Sign in | `POST /api/store/member/signin` `{"login":"kim","password":"pw-12345"}` | 200, the member; a session cookie. Wrong password 401 `Wrong login or password` |
| Who am I | `GET /api/store/member/me` | 200, the member; 401 when not signed in |
| Sign out | `POST /api/store/member/signout` | 204; `me` is 401 after it |
| Another member's record | `GET /api/store/member/{their id}` | 404 |
| Products | `GET /api/store/product/{id}`, `POST /api/store/product/search` `{"name":"fish"}` | 200, without signing in |
| Add or change a product | `POST /api/store/product` `{"name":"Koi","price":25.00}`; `PUT` with `productId` | 200 as `admin`; 401 not signed in, 403 as a member |
| Place an order | `POST /api/store/purchaseOrder` `{"lines":[{"productId":1,"quantity":2}],"card":{"cardNumber":"4111111111111111","cardType":"VISA","expiry":"12/30"}}` | 200: `status` `PLC`, `orderedAt` now, each line's `unitPrice` the product's price and `subTotal`, `total` their sum; no `cardNumber`; the member is the one signed in |
| Not signed in | the same | 401 |
| An order without lines | `"lines":[]`, or no `lines` | 400, `fieldErrors`: `lines` |
| An unknown product | `"lines":[{"productId":99999,"quantity":1}]` | 404, `code` `reference.OrderLine.product`, `detail` "Product 99999 does not exist" |
| A bad expiry | `"expiry":"13/30"` | 400, "expiry must be MM/YY" |
| My orders | `POST /api/store/purchaseOrder/search` `{}` | 200, a page of the signed-in member's orders, newest first; the administrator's has every order |
| Another member's order | `GET /api/store/purchaseOrder/{id}` | 404 |
| Ship | `POST /api/store/purchaseOrder/{id}/ship` | 200 `SHP` as `admin`; 403 as a member; 409 when not `PLC` |
| Cancel | `POST /api/store/purchaseOrder/{id}/cancel` | 200 `CAN` by its member; 409 `state.PurchaseOrder.status.cancel` when shipped |
| Delete | `DELETE /api/store/purchaseOrder/{id}` | 200 as `admin` when `CAN`; 409 otherwise; 403 as a member |
| The report | `GET /api/store/purchaseOrder/report` | 200 `{"countByStatus":{"PLACED":1,...},"revenue":...}` as `admin`; 401, 403 |

After a ship or a cancel the application log has `order 3 SHIPPED total=20.00`.

```bash
curl -s -c jar -b jar -X POST localhost:PORT/api/store/member/signin -H 'Content-Type: application/json' \
     -d '{"login":"admin","password":"admin-1234"}'
curl -s -c jar -b jar -X POST localhost:PORT/api/store/purchaseOrder/1/ship
curl -s -c jar -b jar localhost:PORT/api/store/purchaseOrder/report
```
