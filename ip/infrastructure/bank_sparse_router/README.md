# Sparse heterogeneous bank router

This packet fixes the user inventory in `bank_config_pkg`: active banks 0–3 and
inactive banks 4–15. The router exposes native-width named physical ports only;
there is no maximum-width all-bank crossbar. Reads have fixed latency three and
II=1 when the single physical port is not contested.

The module routes payloads but does not instantiate memory, acquire ownership,
arbitrate DMA streams, implement systolic arithmetic, or provide board logic.
