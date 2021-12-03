ALTER TABLE benchmark_metadata
    ADD cancelled boolean DEFAULT FALSE,
    ADD cancel_reason TEXT;
