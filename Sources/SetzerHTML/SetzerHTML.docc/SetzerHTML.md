# ``SetzerHTML``

Render validated Markdown trees as complete or progressively requested HTML.

## Overview

`HTMLRenderer` escapes raw HTML and neutralises dangerous decoded URLs by
default. Allowing raw HTML is explicit, and does not sanitise it. Renderer hooks
produce trusted caller markup. The conformance renderer is for trusted test
fixtures, not production untrusted input.

`prepare` retains a fully parsed document and creates structural output groups.
Source-byte budgets are soft: giant blocks remain indivisible. Inspect the
plan's mode for whole-document fallbacks. Callers own cancellation, scheduling,
revision checks and layout; grouping does not establish a peak-memory bound.

## Topics

### HTML and hooks
- ``HTMLRenderer``
- ``HTMLRendering``
- ``HTMLRendererHook``
- ``ContextualHTMLRendererHook``
- ``HTMLRendererContext``
- ``HTMLURLScheme``

### Progressive output
- ``HTMLRenderPlan``
- ``HTMLRenderGroup``
- ``HTMLRenderPlanError``
- ``HTMLHookBehavior``
