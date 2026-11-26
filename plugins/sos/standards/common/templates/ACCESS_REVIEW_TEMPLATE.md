# Access Review Template

Use this template for periodic access reviews (target: at least quarterly for production and regulated systems).

## Metadata

- Review period:
- System / scope:
- Owner:
- Reviewers:
- Frameworks in scope (SOC 2, ISO 27001, GDPR, HIPAA, PCI DSS, internal):

## Scope

- Identity providers / directories included:
- Systems / repositories / cloud accounts included:
- Roles / groups in scope:
- Service accounts in scope:

## Method

- Source of record (IdP export, cloud IAM export, ticketing exports):
- Reviewer assignment (manager, system owner, data owner):
- Action options (keep, modify scope, revoke, escalate):

## Findings

| Principal | Type (user / service) | System / role | Last activity | Decision (keep / modify / revoke) | Reviewer | Action ticket |
|-----------|----------------------|---------------|---------------|----------------------------------|----------|---------------|
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |

## Privileged Access (just-in-time)

- Number of JIT elevations in period:
- % approved within SLA:
- Any elevations without a linked ticket / approval (must be remediated):

## Service Accounts

- [ ] Each service account has an owner.
- [ ] Each service account has a documented purpose and scope.
- [ ] Rotation policy met for credentials and keys.
- [ ] Decommission list (no owner, no usage):

## Leavers / Movers

- [ ] All leavers since last review are deprovisioned within SLA.
- [ ] Internal movers had access updated to new role.
- [ ] Evidence (IdP audit log, ticket close timestamps) attached.

## Exceptions

- Documented exceptions with owner, expiry, and compensating control:

## Sign-Off

- System owner:
- Security / compliance:
- Date:
- Evidence link:
