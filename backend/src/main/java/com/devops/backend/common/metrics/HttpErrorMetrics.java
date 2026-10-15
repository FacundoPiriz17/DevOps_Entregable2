package com.devops.backend.common.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.stereotype.Component;

@Component
public class HttpErrorMetrics {

    private final Counter http500Errors;

    public HttpErrorMetrics(MeterRegistry registry) {
        this.http500Errors = Counter.builder("http_500_errors")
                .description("Total HTTP 500 errors")
                .register(registry);
    }

    public void recordError() {
        http500Errors.increment();
    }
}