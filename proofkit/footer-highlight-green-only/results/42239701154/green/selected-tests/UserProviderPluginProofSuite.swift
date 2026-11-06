#if canImport(JavaScriptCore)
import Testing

// Proof-only namespace shell: preserve the product suite's serialization while
// excluding unrelated test methods and their screenshot-only dependencies.
@Suite(.serialized)
struct UserProviderPluginTests {}
#endif
