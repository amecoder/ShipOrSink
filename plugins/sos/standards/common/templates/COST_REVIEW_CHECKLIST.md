# Cost Review Checklist

Use this checklist for infrastructure, data, AI, and high-traffic feature changes.

## Change

- System:
- Owner:
- Environment:
- Expected launch:

## Estimate

- [ ] Monthly cost estimate is documented.
- [ ] Main scaling driver is known.
- [ ] Cost owner or team tag is defined.
- [ ] Load or usage assumptions are documented.

## Guardrails

- [ ] Autoscaling limits are set.
- [ ] Quotas or rate limits exist where needed.
- [ ] Retention and cleanup jobs are defined.
- [ ] Budget or anomaly alerts exist.
- [ ] Kill switch or rollback path exists for runaway spend.

## AI/LLM

- [ ] Token/transcription/embedding/image cost is estimated.
- [ ] Retry and fallback behavior is bounded.
- [ ] Cheaper model or cache option was evaluated.
- [ ] Cost is tracked by model and feature.

## Approval

- Approved by:
- Date:
- Follow-up:
