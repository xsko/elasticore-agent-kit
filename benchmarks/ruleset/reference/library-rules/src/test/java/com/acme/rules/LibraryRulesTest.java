package com.acme.rules;

import io.elasticore.base.model.pub.rules.EntitySpec;
import io.elasticore.base.model.pub.rules.ModelCheck;
import io.elasticore.base.model.pub.rules.RuleCatalog;
import io.elasticore.base.model.pub.rules.RuleEngine;
import io.elasticore.base.model.pub.rules.SourceCode;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** The rules on a small model written here - no project, no generation run. */
class LibraryRulesTest {

    private static final String PKG = "com.acme.library";

    @AfterEach
    void forget() {
        ModelCheck.reset();
    }

    private RuleEngine engine() {
        return RuleCatalog.standard().engineFor("hexagonal-springboot")
                .register(new LibraryRules())
                .templateSet(SourceCode.TemplateSet.V3);
    }

    private EntitySpec member(String expose) {
        return new EntitySpec("Member")
                .domain("library", "Library")
                .meta("root", "")
                .meta("expose", expose)
                .pkg("entity", PKG + ".domain.model")
                .pkg("dto", PKG + ".application.dto")
                .pkg("srchdto", PKG + ".application.dto")
                .pkg("control", PKG + ".adapter.in.web")
                .field("memberId", "long @id @sequence")
                .field("name", "string(50)! @search(like)")
                .field("email", "string(100)! @email @pii");
    }

    @Test
    void piiIsWriteOnly() {
        String out = engine().run(member("20"), "dto").render();
        assertTrue(out.contains("@JsonProperty(access = JsonProperty.Access.WRITE_ONLY)"), out);
    }

    @Test
    void likeNeedsTwoCharacters() {
        String out = engine().run(member("20"), "srchdto").render();
        assertTrue(out.contains("@Size(min = 2)"), out);
    }

    @Test
    void noDeleteTakesTheEndpointsAway() {
        String out = engine().run(member("20").meta("nodelete", ""), "control").render();
        assertFalse(out.contains("@DeleteMapping"), out);
    }

    @Test
    void aPageAboveFiftyFails() {
        engine().run(member("80"), "entity");
        assertEquals(1, ModelCheck.failures().size());
        assertTrue(ModelCheck.failures().get(0).contains("Member"));
    }
}
