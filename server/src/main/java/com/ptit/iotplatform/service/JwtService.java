package com.ptit.iotplatform.service;

import com.nimbusds.jose.*;
import com.nimbusds.jose.crypto.*;
import com.nimbusds.jwt.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Base64;
import java.util.Date;

@Service
public class JwtService {

    private final byte[] sharedSecret;
    private final JWSSigner signer;
    private final JWSVerifier verifier;

    public JwtService(@Value("${jwt.secret:dGhpcy1pcy1hLXZlcnktc2VjdXJlLTMyLWJ5dGUtc2VjcmV0LWtleS1mb3Itand0LXNpZ25pbmc=}") String secret) throws Exception {
        this.sharedSecret = Base64.getDecoder().decode(secret);
        this.signer = new MACSigner(this.sharedSecret);
        this.verifier = new MACVerifier(this.sharedSecret);
    }

    public String generateToken(String username, String tbToken) {
        try {
            JWTClaimsSet claimsSet = new JWTClaimsSet.Builder()
                    .subject(username)
                    .issueTime(new Date())
                    .expirationTime(new Date(System.currentTimeMillis() + 86400 * 1000)) // 24 hours
                    .claim("tb_token", tbToken)
                    .build();

            SignedJWT signedJWT = new SignedJWT(new JWSHeader(JWSAlgorithm.HS256), claimsSet);
            signedJWT.sign(signer);
            return signedJWT.serialize();
        } catch (JOSEException e) {
            throw new RuntimeException("Error signing JWT", e);
        }
    }

    public JWTClaimsSet parseAndValidateToken(String token) {
        try {
            SignedJWT signedJWT = SignedJWT.parse(token);
            if (!signedJWT.verify(verifier)) {
                return null;
            }
            JWTClaimsSet claimsSet = signedJWT.getJWTClaimsSet();
            if (new Date().after(claimsSet.getExpirationTime())) {
                return null;
            }
            return claimsSet;
        } catch (Exception e) {
            return null;
        }
    }
}
