---
paths:
  - "**/*.{py,ts,tsx,js,jsx,java,kt,kts,cs,go,rs,rb,swift,dart}"
---

# Object-Oriented Design Rules

Objects exist to protect invariants and hide decisions. Use them where state and the rules about that state belong together; do not use them as namespaces for procedures.

## SOLID, One Line Each

- **Single responsibility**: a class has one reason to change. `OrderPricing` computes prices; it does not also send emails or write rows.
- **Open/closed**: add behavior by adding a new implementation, not by editing a growing `switch`. New payment method → new `PaymentMethod` class, not another `case`.
- **Liskov substitution**: a subtype must be usable wherever the base type is expected without surprising callers. A `ReadOnlyRepository` that throws on `save()` is not a `Repository`.
- **Interface segregation**: consumers depend on the smallest interface they need. A report reader takes `OrderReader`, not the whole `OrderRepository`.
- **Dependency inversion**: high-level policy depends on abstractions it owns. `Billing` defines the `PaymentGateway` port; `StripeGateway` in infrastructure implements it.

## Design Rules

- Prefer composition over inheritance. Inherit only for a genuine is-a relationship with a stable base; otherwise inject collaborators.
- Keep invariants inside the object: constructors and methods reject invalid state, so callers never need to re-validate. `Money.of(-1)` throws; nothing downstream checks for negative money.
- Tell, don't ask: call `account.withdraw(amount)` instead of reading `account.balance`, deciding, then setting it. Logic that needs an object's data belongs on that object.
- Define interfaces on the consumer side, in the consumer's module, named for the capability (`Clock`, `Notifier`), not for the implementation (`SystemClockImpl`).
- Value objects are immutable and compared by value (`Email`, `Money`, `DateRange`); entities have identity and a lifecycle (`Order`, `User`). Do not give value objects setters.
- Avoid anemic models for core behavior: if every rule lives in a service and the model is a bag of getters and setters, move the rules into the model or document why not.
- No god classes: split when a class exceeds roughly 300 lines, has more than one axis of change, or its name needs "Manager", "Helper", or "Util" to make sense.
- Law of Demeter: one dot for behavior (`order.customer().email()` is a smell; expose `order.customerEmail()` or pass the needed value in).
- Constructors do assignment and validation only; no I/O, no network, no reading config at construction time.

## Language Notes

- Python: `@dataclass(frozen=True)` for value objects, `Protocol` for consumer-side interfaces, avoid multiple inheritance beyond mixins.
- TypeScript: `interface` for ports, `readonly` fields, classes only when state and behavior belong together; plain functions otherwise.
- Java/Kotlin: `record` / `data class` for values, `sealed` hierarchies for closed variants, final by default.
- Go: small interfaces defined by the consumer, struct embedding over inheritance, constructors return concrete types.
- Rust: traits as interfaces, newtype pattern for value objects, enums for closed variants.

## Review Checklist

- Each class has one reason to change and its name says what it is, not what it does to others.
- Invalid states cannot be constructed.
- No subtype weakens a base-type guarantee.
- Collaborators are injected through consumer-owned interfaces.
- Behavior lives with the data it operates on; services orchestrate rather than decide.
