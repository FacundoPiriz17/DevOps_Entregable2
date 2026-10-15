
package com.devops.backend.common.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.stereotype.Component;

@Component
public class LoginMetrics {

    private final Counter failedLogins;

    public LoginMetrics(MeterRegistry registry) {
        this.failedLogins = Counter.builder("failed_logins")
                .description("Total number of failed login attempts")
                .register(registry);
    }

    public void recordFailedLogin() {
        failedLogins.increment();
    }
}
