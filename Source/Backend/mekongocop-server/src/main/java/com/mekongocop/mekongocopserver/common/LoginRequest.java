package com.mekongocop.mekongocopserver.common;

import lombok.Getter;

@Getter
public class LoginRequest {
    public LoginRequest(String username, String password) {
        this.username = username;
        this.password = password;
    }
    public LoginRequest() {}
    public void setUsername(String username) {
        this.username = username;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getUsername() {
        return username;
    }

    public String getPassword() {
        return password;
    }

    private String username;
    private String password;
}
