package com.mekongocop.mekongocopserver.controller;

import com.mekongocop.mekongocopserver.common.StatusResponse;
import com.mekongocop.mekongocopserver.dto.UserProfileDTO;
import com.mekongocop.mekongocopserver.entity.UserProfile;
import com.mekongocop.mekongocopserver.service.UserProfileService;
import com.mekongocop.mekongocopserver.util.JwtTokenProvider;
import com.mekongocop.mekongocopserver.util.TokenExtractor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/api/v1/user")
public class UserProfileController {
    @Autowired
    private UserProfileService userProfileService;
    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @PostMapping("/profile")
    public CompletableFuture<ResponseEntity<StatusResponse<UserProfileDTO>>> addUserProfile(
            @RequestPart("dto") String dto,
            @RequestPart("file") MultipartFile file) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                UserProfileDTO userProfileDTO = userProfileService.convertJsonToDTO(dto);
                userProfileService.addProfile(userProfileDTO, file);
                return ResponseEntity.ok(new StatusResponse<>("Success", "Add profile successfully", userProfileDTO));
            } catch (Exception e) {
                return ResponseEntity.internalServerError().body(new StatusResponse<>("Error", "Failed to add profile", null));
            }
        });
    }

    @PutMapping("/profile")
    public ResponseEntity<StatusResponse<UserProfileDTO>> updateUserProfile(@RequestHeader("Authorization") String authHeader, @RequestBody UserProfileDTO userProfileDTO) {

        String token = String.valueOf(jwtTokenProvider.validateToken(authHeader));
        if (token == null) {
            return ResponseEntity.badRequest().body(new StatusResponse<>("Error", "Invalid token", null));
        }

        try {
            String tokenCheck = TokenExtractor.extractToken(authHeader);
            userProfileService.updateProfile(tokenCheck, userProfileDTO);
            return ResponseEntity.ok(new StatusResponse<>("Success", "Profile updated successfully", userProfileDTO));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new StatusResponse<>("Error", e.getMessage(), null));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(new StatusResponse<>("Error", "An error occurred while updating profile", null));
        }
    }

    @PatchMapping("/profile/bio")
    public ResponseEntity<StatusResponse<String>> updateBio(@RequestHeader("Authorization") String authHeader, @RequestBody UserProfileDTO userProfileDTO) {
        String token = String.valueOf(jwtTokenProvider.validateToken(authHeader));
        if (token == null) {
            return ResponseEntity.badRequest().body(new StatusResponse<>("Error", "Invalid token", null));
        }

        try{
            String validToken = TokenExtractor.extractToken(authHeader);
                userProfileService.updateBio(validToken, userProfileDTO);
                return ResponseEntity.ok(new StatusResponse<>("Success", "Update bio successfully", null));
        }catch (IllegalArgumentException e){
            return ResponseEntity.badRequest().body(new StatusResponse<>("Error", e.getMessage(), null));
        }catch (Exception e){
            return ResponseEntity.internalServerError().body(new StatusResponse<>("Error", e.getMessage(), null));
        }
    }

}