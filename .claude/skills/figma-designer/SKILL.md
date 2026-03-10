---
name: figma-designer
description: |
  Analyze Figma designs and translate them into Flutter implementation guidance.
  Wraps any design question with project-specific context about existing UI
  components, theming, and conventions. Invoke with /figma-designer.
author: Daniel Cadenas
version: 1.0.0
user_invocable: true
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
5. Provide implementation guidance or code that reuses existing components
