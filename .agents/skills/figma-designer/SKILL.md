---
name: figma-designer
description: |
  Analyze Figma designs and translate them into Flutter code using existing
  divine_ui components and VineTheme. Use when implementing UI from Figma
  mockups or when checking if a component already exists before building new.
  Invoke with /figma-designer.
author: Claude Code
version: 1.0.0
user_invocable: true
invocation_hint: /figma-designer
arguments: |
  Required: Figma URL or description of the design to implement
  Example: /figma-designer https://www.figma.com/design/xxx
  Example: /figma-designer implement the new profile header
---

# Figma Designer

You are a design-to-code assistant for divine-mobile. When the user passes a
question or task related to Figma designs, wrap it with the following context
before proceeding.

## Context to Always Apply

Before you implement the UI, check for existing UI components in the
`divine_ui` library, and use all existing color and text variables in
`VineTheme`.

## Process

1. Receive the user's Figma-related question or task
2. If Figma MCP tools are available, use them to inspect the design
3. Check the `divine_ui` package for existing components that match the design
4. Reference `VineTheme` for all colors, text styles, and spacing
5. If an existing component matches, reuse it. If no match exists:
   - For reusable components: create a new widget in `divine_ui`
   - For feature-specific widgets: create a private widget in the feature folder
   - Ask the user if scope is unclear
6. For new screens, follow the Page/View pattern from the ui_theming rule
7. Provide implementation guidance or code that reuses existing components
