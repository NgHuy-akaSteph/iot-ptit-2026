package com.ptit.iotplatform.config;

import com.nimbusds.jwt.JWTClaimsSet;
import com.ptit.iotplatform.service.JwtService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtService jwtService;

    public SecurityConfig(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .cors(AbstractHttpConfigurer::disable)
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/login", "/api/devices/telemetry/webhook", "/error").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(new BffJwtFilter(jwtService), UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    private static class BffJwtFilter extends OncePerRequestFilter {
        private final JwtService jwtService;

        public BffJwtFilter(JwtService jwtService) {
            this.jwtService = jwtService;
        }

        @Override
        protected boolean shouldNotFilterAsyncDispatch() {
            return false;
        }

        @Override
        protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
                throws ServletException, IOException {
            String header = request.getHeader(HttpHeaders.AUTHORIZATION);

            if (header != null && header.startsWith("Bearer ")) {
                String token = header.substring(7);
                JWTClaimsSet claims = jwtService.parseAndValidateToken(token);

                if (claims != null) {
                    String username = claims.getSubject();
                    String tbToken = (String) claims.getClaim("tb_token");

                    if (username != null && tbToken != null) {
                        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                                username,
                                tbToken, // Put ThingsBoard token as credentials
                                Collections.emptyList()
                        );
                        SecurityContextHolder.getContext().setAuthentication(auth);
                    }
                }
            }

            filterChain.doFilter(request, response);
        }
    }
}
