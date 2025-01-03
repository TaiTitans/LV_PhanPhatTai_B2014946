package com.mekongocop.mekongocopserver.util;

import com.mekongocop.mekongocopserver.dto.UserDTO;
import com.mekongocop.mekongocopserver.entity.Role;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Component
public class JwtTokenProvider {

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.access-token-expiration-in-ms}")
    private long accessTokenExpirationInMs;

    @Value("${jwt.refresh-token-expiration-in-ms}")
    private long refreshTokenExpirationInMs;

    public String extractUsername(String token) {
        return getClaimFromToken(token, Claims::getSubject);
    }

    public Date getExpirationDateFromToken(String token) {
        return getClaimFromToken(token, Claims::getExpiration);
    }

    public <T> T getClaimFromToken(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = getAllClaimsFromToken(token);
        return claimsResolver.apply(claims);
    }

    private Claims getAllClaimsFromToken(String token) {
        return Jwts.parser().setSigningKey(secret).parseClaimsJws(token).getBody();
    }

    public boolean isTokenExpired(String token) {
        try {
            Date expirationDate = parseClaims(token).getExpiration();
            return expirationDate.before(new Date());
        } catch (ExpiredJwtException e) {
            return true;
        }
    }


    public String generateAccessToken(UserDTO userDTO) {
        return Jwts.builder()
                .setSubject(String.format("%s,%s", userDTO.getUser_id(), userDTO.getUsername()))
                .setIssuer("TitansDev")
                .claim("roles", userDTO.getRoles())
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis()+ accessTokenExpirationInMs))
                .signWith(SignatureAlgorithm.HS512, secret)
                .compact();
    }

    public String generateRefreshToken(UserDTO userDTO) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("user_id", userDTO.getUser_id());
        claims.put("roles", userDTO.getRoles());
        return doGenerateToken(claims, userDTO.getUsername(), refreshTokenExpirationInMs);
    }


    private String doGenerateToken(Map<String, Object> claims, String subject, long expirationInMs) {
        return Jwts.builder()
                .setClaims(claims)
                .setSubject(subject)
                .setIssuedAt(new Date(System.currentTimeMillis()))
                .setExpiration(new Date(System.currentTimeMillis() + expirationInMs))
                .signWith(SignatureAlgorithm.HS512, secret)
                .compact();
    }

    public String getTokenFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }

    public boolean validateToken(String authHeader) {
        String token = TokenExtractor.extractToken(authHeader);
        if (token == null) {
            return false;
        }
        try {
            System.out.println("Token received: " + token);
            Jwts.parser().setSigningKey(secret).parseClaimsJws(token);
            return !isTokenExpired(token);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
    public Claims parseClaims(String token) {
        return Jwts.parser()
                .setSigningKey(secret)
                .parseClaimsJws(token)
                .getBody();
    }

    public int getUserIdFromToken(String token) {
        return getClaimFromToken(token, claims -> Integer.parseInt(claims.getSubject().split(",")[0]));
    }
    public String getUsernameFromToken(String token) {
        return getClaimFromToken(token, claims -> claims.getSubject().split(",")[1]);
    }
}
