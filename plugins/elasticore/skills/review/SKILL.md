---
name: review
description: Review a change in an ElastiCORE project with the elasticore:reviewer agent - hand edits to generated files, DSL checked against the project's guides, generated code in step with the DSL, and the business impact.
disable-model-invocation: true
argument-hint: "[git range or branch - default: changes not yet committed]"
---

# Review

Hand the review to the `elasticore:reviewer` agent with the range `$ARGUMENTS` (none given: the
changes not yet committed). Pass on its report as it is - findings first, then what changes for the
business, then what it checked. Do not fix anything unless the user asks afterwards.
