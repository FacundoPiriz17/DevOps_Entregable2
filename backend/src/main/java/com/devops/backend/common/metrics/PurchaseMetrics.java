package com.devops.backend.common.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;

import org.springframework.stereotype.Component;

@Component
public class PurchaseMetrics {

    private final Counter totalPurchases;
    private final Counter totalEarnings;

    public PurchaseMetrics(MeterRegistry registry) {
        this.totalPurchases = Counter.builder("total_purchases")
                .description("Total number of successfully completed purchases")
                .register(registry);

        this.totalEarnings = Counter.builder("total_earnings")
            .description("Total earnings made by successfully completed purchases")
            .baseUnit("currency units")
            .register(registry);
    }

    public void recordPurchase() {
        totalPurchases.increment();
    }

    public void recordEarnings(double amount) {
        if (amount > 0) {
            totalEarnings.increment(amount);
        }
    }
}