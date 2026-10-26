package com.acme.rules;

import io.elasticore.base.model.pub.rules.AnnoCode;
import io.elasticore.base.model.pub.rules.CodeRules;
import io.elasticore.base.model.pub.rules.EntitySpec;
import io.elasticore.base.model.pub.rules.FieldSpec;
import io.elasticore.base.model.pub.rules.ModelCheck;
import io.elasticore.base.model.pub.rules.Rule;

import static io.elasticore.base.model.pub.rules.Ctx.ctx;

/** The reference answer to task.ko.md: the four team rules, written as the rule dev guide teaches. */
public class LibraryRules implements CodeRules {

    /** 1. A field marked @pii is accepted in requests but never sent back in responses. */
    @Rule(value = "acme-pii", target = "dto")
    void pii(EntitySpec dto, FieldSpec f) {
        if (f.hasDsl("pii")) {
            ctx(dto).field(f).ensure(AnnoCode.of("com.fasterxml.jackson.annotation.JsonProperty")
                    .valRaw("access", "JsonProperty.Access.WRITE_ONLY"));
        }
    }

    /** 2. meta @nodelete: the REST API has no delete endpoints (deleteBatch goes with deleteById). */
    @Rule(value = "acme-no-delete", target = "control")
    void noDelete(EntitySpec e) {
        if (e.hasMeta("nodelete")) ctx(e).excludeMethod("deleteById");
    }

    /** 3. A LIKE search term has at least 2 characters. */
    @Rule(value = "acme-like-min", target = "srchdto")
    void likeMin(EntitySpec search, FieldSpec f) {
        if ("like".equals(f.dslValue("search"))) {
            ctx(search).field(f).ensure(AnnoCode.of("jakarta.validation.constraints.Size").val("min", 2));
        }
    }

    /** 4. A page of more than 50 rows fails the build. */
    @Rule("acme-page-size")
    void pageSize(EntitySpec e) {
        String expose = e.metaValue("expose");
        if (expose != null && expose.trim().matches("\\d+") && Integer.parseInt(expose.trim()) > 50) {
            ModelCheck.fail(String.format("[acme] %s pages %s rows at a time (@expose(%s)); the team maximum is 50.",
                    e.getName(), expose.trim(), expose.trim()));
        }
    }
}
