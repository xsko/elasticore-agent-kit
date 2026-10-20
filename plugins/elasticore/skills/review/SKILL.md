---
name: review
description: Review a change in an ElastiCORE project with the elasticore:reviewer agent - hand edits to generated files, DSL checked against the project's guides and the generator the build runs, and the business impact. Reads only, unless asked for a full check with a build.
disable-model-invocation: true
argument-hint: "[git range or branch - default: changes not yet committed] [full: also build]"
---

# Review

Hand the review to the `elasticore:reviewer` agent with the range `$ARGUMENTS` (none given: the
changes not yet committed). Ask it to build - which regenerates and writes files - only when the
arguments contain `full`. Pass on its report as it is: findings first, then what changes for the
business, then what it checked. Do not fix anything unless the user asks afterwards.
