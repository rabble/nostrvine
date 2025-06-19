# Multi-Agent Pull Request

## Agent Information
**Agent:** [Agent Name]  
**Work Area:** [UI/Services/Data/Testing/Platform]  
**Estimated Time Spent:** [X hours]

## Summary
Brief description of changes made.

## Type of Change
- [ ] 🚀 New feature
- [ ] 🐛 Bug fix  
- [ ] 🔧 Refactoring
- [ ] 📝 Documentation
- [ ] 🧪 Tests
- [ ] ⚡ Performance improvement
- [ ] 🔒 Security fix

## Files Modified
List the key files changed and why:
- `lib/services/example.dart` - Added new functionality
- `test/services/example_test.dart` - Added test coverage

## Multi-Agent Coordination
- [ ] **File Locks**: All claimed files have been released
- [ ] **Dependencies**: No blocking dependencies remain  
- [ ] **Integration Points**: Verified compatibility with other agent work
- [ ] **Shared Interfaces**: No breaking changes to shared contracts

## Testing Checklist
- [ ] **Unit Tests**: New/modified code has unit test coverage
- [ ] **Widget Tests**: UI changes have widget tests
- [ ] **Integration Tests**: Feature works end-to-end
- [ ] **Manual Testing**: Verified on target platforms
- [ ] **Regression Testing**: Existing functionality still works

## Quality Gates
- [ ] **Flutter Analyze**: `flutter analyze` passes with no issues
- [ ] **All Tests Pass**: `flutter test` completes successfully  
- [ ] **Code Coverage**: Coverage maintained or improved
- [ ] **Performance**: No performance regressions introduced
- [ ] **Documentation**: Code is properly documented

## Agent Review Required
Tag other agents whose work areas intersect:
- @agent-ui (if UI changes affect services)
- @agent-services (if service interfaces changed)
- @agent-testing (if test infrastructure modified)

## Deployment Notes
Any special considerations for deployment:
- [ ] Database migrations required
- [ ] Configuration changes needed
- [ ] Platform-specific considerations
- [ ] Breaking changes (requires coordination)

## Rollback Plan
If issues arise after merge:
- [ ] Rollback strategy documented
- [ ] Feature flags in place (if applicable)
- [ ] Monitoring/alerting considerations

---

**Definition of Done Verified:**
- [ ] All acceptance criteria met
- [ ] Code reviewed by another agent
- [ ] All automated checks passing
- [ ] Ready for production deployment