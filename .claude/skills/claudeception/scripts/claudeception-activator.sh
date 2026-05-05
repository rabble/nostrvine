#!/bin/bash

# Claudeception Auto-Activation Hook
# This hook ensures the claudeception skill evaluates every interaction
# for journal-worthy knowledge worth preserving.
#
# Installation:
#   1. Copy this script to ~/.claude/hooks/
#   2. Make it executable: chmod +x ~/.claude/hooks/claudeception-activator.sh
#   3. Add to ~/.claude/settings.json (see README for details)

cat << 'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧠 MANDATORY JOURNAL EVALUATION REQUIRED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CRITICAL: After completing this user request, you MUST evaluate whether
it produced journal-worthy knowledge using the claudeception skill.

EVALUATION PROTOCOL (NON-NEGOTIABLE):

1. COMPLETE the user's request first
2. EVALUATE: Ask yourself:
   - Did this require non-obvious investigation or debugging?
   - Was the solution something that would help in future similar situations?
   - Did I discover something not immediately obvious from documentation?

3. IF YES to any question above:
   ACTIVATE: Use Skill(claudeception) NOW to capture the knowledge
   as a dated journal entry under ~/.claude/journal

4. IF NO to all questions:
   SKIP: No journal entry needed

This is NOT optional. Failing to evaluate means valuable knowledge is lost.
The claudeception skill will decide whether to actually write a new
journal entry based on its quality criteria.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
