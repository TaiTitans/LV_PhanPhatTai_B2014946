package com.mekongocop.mekongocopserver.service;

import com.mekongocop.mekongocopserver.dto.*;
import com.mekongocop.mekongocopserver.entity.*;
import com.mekongocop.mekongocopserver.repository.*;
import com.mekongocop.mekongocopserver.util.JwtTokenProvider;
import jakarta.transaction.Transactional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.util.Date;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class OrderService {
    public static final Logger log = LoggerFactory.getLogger(OrderService.class);

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private OrderItemService orderItemService;

    @Autowired
    private CartService cartService;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProductRepository productRepository;
    @Autowired
    private OrderItemRepository orderItemRepository;

    @Autowired
    private VietQRService vietQRService;
    @Autowired
    private StoreRepository storeRepository;

    public OrderDTO convertToDTO(Order order) {
        OrderDTO orderDTO = new OrderDTO();
        orderDTO.setOrder_id(order.getOrder_id());
        orderDTO.setTotal_price(order.getTotal_price());
        orderDTO.setPayment(order.getPayment());
        orderDTO.setStatus(order.getStatus());
        orderDTO.setAddress(order.getAddress());
        orderDTO.setShip(order.getShip());
        orderDTO.setQr_code_url(order.getQr_code_url());
        orderDTO.setCreated_at(order.getCreated_at());
        orderDTO.setUpdated_at(order.getUpdated_at());

        // Chuyển đổi danh sách OrderItem entity sang DTO
        orderDTO.setItems(order.getItems().stream()
                .map(orderItemService::convertOrderItemEntityToDTO)
                .collect(Collectors.toList()));

        return orderDTO;
    }

    public Order convertToEntity(OrderDTO orderDTO) {
        Order order = new Order();
        order.setOrder_id(orderDTO.getOrder_id());
        order.setTotal_price(orderDTO.getTotal_price());
        order.setPayment(orderDTO.getPayment());
        order.setStatus(orderDTO.getStatus());
        order.setAddress(orderDTO.getAddress());
        order.setShip(orderDTO.getShip());
        order.setQr_code_url(orderDTO.getQr_code_url());
        order.setCreated_at(orderDTO.getCreated_at());
        order.setUpdated_at(orderDTO.getUpdated_at());

        // Lấy user từ user_id và gán vào order
        User user = userRepository.findById(orderDTO.getUser_id())
                .orElseThrow(() -> new RuntimeException("User not found"));
        order.setUser(user);  // Gán User vào Order

        // Chuyển đổi danh sách OrderItemDTO sang entity
        order.setItems(orderDTO.getItems().stream()
                .map(orderItemDTO -> orderItemService.convertOrderItemDTOToEntity(orderItemDTO, order, productRepository.findById(orderItemDTO.getProductId()).orElseThrow()))
                .collect(Collectors.toList()));

        return order;
    }





    // Lấy tất cả đơn hàng của 1 người dùng
    public List<OrderDTO> getAllOrdersByUserId(String token) {
        try {
            int userId = jwtTokenProvider.getUserIdFromToken(token);
            List<Order> orders = orderRepository.findByUserId(userId);
            return orders.stream()
                    .map(this::convertToDTO)
                    .collect(Collectors.toList());
        }catch (Exception e){
            throw new RuntimeException(e);
        }
    }

    // Lấy đơn hàng cụ thể của người dùng từ token
    public OrderDTO getOrderById(String token, int orderId) {
        try {
            int userId = jwtTokenProvider.getUserIdFromToken(token); // Lấy userId từ token

            Order order = orderRepository.findById(orderId)
                    .orElseThrow(() -> new RuntimeException("Order not found"));

            // Kiểm tra xem đơn hàng có thuộc về người dùng không
            if (order.getUser().getUser_id() != userId) {
                throw new RuntimeException("You do not have permission to view this order");
            }

            return convertToDTO(order);
        }catch (Exception e){
            throw new RuntimeException(e);
        }
    }


    public List<OrderDTO> getOrderByStore(String token){
        try {
            // Lấy userId từ token
            int userId = jwtTokenProvider.getUserIdFromToken(token);

            // Tìm kiếm Store dựa trên userId
            Optional<Store> storeOptional = storeRepository.findByUserId(userId);

            if (storeOptional.isPresent()) {
                // Lấy storeEntity từ Optional
                Store storeEntity = storeOptional.get();

                // Lấy danh sách Order dựa trên store_id
                List<Order> orders = orderRepository.findOrdersByStoreId(storeEntity.getStore_id());

                // Chuyển đổi từ Order sang OrderDTO
                return orders.stream()
                        .map(this::convertToDTO) // Hàm chuyển đổi từ Order sang OrderDTO
                        .collect(Collectors.toList());
            } else {
                throw new RuntimeException("Store not found for the user.");
            }
        } catch (Exception e) {
            throw new RuntimeException("Error retrieving orders: " + e.getMessage(), e);
        }
    }


// ORDER========================================================================================================

    private OrderDTO createOrderDTO(int userId, CartDTO cart, BigDecimal totalPrice) {
        OrderDTO orderDTO = new OrderDTO();
        orderDTO.setShip(BigDecimal.valueOf(30000));
        orderDTO.setUser_id(userId);
        orderDTO.setTotal_price(totalPrice.add(orderDTO.getShip()));
        orderDTO.setItems(cart.getCartItemList().stream().map(cartItem -> {
            OrderItemDTO orderItemDTO = new OrderItemDTO();
            orderItemDTO.setProductId(cartItem.getProductId());
            orderItemDTO.setQuantity(cartItem.getQuantity());
            orderItemDTO.setPrice(cartItem.getPrice());
            return orderItemDTO;
        }).collect(Collectors.toList()));
        orderDTO.setCreated_at(new Timestamp(new Date().getTime()));
        orderDTO.setUpdated_at(new Timestamp(new Date().getTime()));
        return orderDTO;
    }
    @Transactional
    public OrderDTO createOrder(String token, String address, String paymentMethod) {
        try {
            int userId = jwtTokenProvider.getUserIdFromToken(token);
            User user = userRepository.findById(userId).orElseThrow(() -> new RuntimeException("User not found"));
            CartDTO cart = cartService.getCartWithProductDetails(token);
            if (cart == null || cart.getCartItemList().isEmpty()) {
                throw new RuntimeException("Cart is empty");
            }

            BigDecimal totalPrice = calculateTotalPrice(cart.getCartItemList());
            OrderDTO orderDTO = createOrderDTO(userId, cart, totalPrice);
            orderDTO.setAddress(address);
            orderDTO.setPayment(paymentMethod);

            // Tạo đơn hàng trước khi gọi processPayment
            Order order = createOrder(orderDTO, user);
            orderDTO.setOrder_id(order.getOrder_id());

            // Gọi processPayment và cập nhật qr_code_url, status
            processPayment(orderDTO, order);

            // Xóa giỏ hàng khỏi Redis sau khi tạo đơn hàng
            cartService.clearCart(token);

            return orderDTO;
        } catch (Exception e) {
            log.error(e.getMessage());
            throw new RuntimeException(e);
        }
    }

    private Order createOrder(OrderDTO orderDTO, User user) {
        Order order = convertToEntity(orderDTO);
        order.setUser(user);
        order.setStatus("Request");
        orderRepository.save(order);
        orderItemService.saveAll(order.getItems());
        return order;
    }

    private void processPayment(OrderDTO orderDTO, Order order) {
        if (orderDTO.getPayment().equals("Cash")) {
            order.setStatus("Request");
        } else if (orderDTO.getPayment().equals("VietQR")) {
            String qrCodeUrl = vietQRService.processVietQRPayment(orderDTO.getTotal_price(), "PHAN PHAT TAI", "0349413880", "Thanh toan MekongOCOP "+ orderDTO.getOrder_id());
            if (qrCodeUrl != null) {
                order.setStatus("Request");
                order.setQr_code_url(qrCodeUrl);
            } else {
                throw new RuntimeException("VietQR payment failed.");
            }
        } else {
            throw new IllegalArgumentException("Invalid payment method: " + orderDTO.getPayment());
        }
        orderRepository.save(order);
        orderDTO.setQr_code_url(order.getQr_code_url());
        orderDTO.setStatus(order.getStatus());
    }
    private BigDecimal calculateTotalPrice(List<CartItemDTO> cartItems) {
        BigDecimal totalPrice = BigDecimal.ZERO;
        for (CartItemDTO cartItem : cartItems) {
            BigDecimal itemTotalPrice = cartItem.getPrice().multiply(new BigDecimal(cartItem.getQuantity()));
            totalPrice = totalPrice.add(itemTotalPrice);
        }
        return totalPrice;
    }

// END ===========================================================================================================

    @Transactional
    public OrderDTO updateOrderStatusToPending(int orderId) {
        try {
            // Lấy đơn hàng theo orderId
            Order order = orderRepository.findById(orderId)
                    .orElseThrow(() -> new RuntimeException("Order not found"));

            // Kiểm tra trạng thái hiện tại có hợp lệ để chuyển sang Pending không
            if (!order.getStatus().equals("Request")) {
                throw new RuntimeException("Order status is not valid for this update");
            }

            // Cập nhật trạng thái đơn hàng
            order.setStatus("Pending");

            // Trừ số lượng sản phẩm tương ứng
            for (OrderItem orderItem : order.getItems()) {
                Product product = orderItem.getProduct();
                if (product.getProduct_quantity() < orderItem.getQuantity()) {
                    throw new RuntimeException("Not enough quantity in stock for product: " + product.getProduct_name());
                }
                // Trừ số lượng sản phẩm
                product.setProduct_quantity(product.getProduct_quantity() - orderItem.getQuantity());
                productRepository.save(product);
            }

            // Cập nhật đơn hàng
            orderRepository.save(order);

            // Trả về DTO sau khi cập nhật
            return convertToDTO(order);
        }catch (Exception e){
            throw new RuntimeException(e);
        }
    }

    @Transactional
    public OrderDTO updateOrderStatusToCancel(int orderId) {
        try {
            // Lấy đơn hàng theo orderId
            Order order = orderRepository.findById(orderId)
                    .orElseThrow(() -> new RuntimeException("Order not found"));

            // Cập nhật trạng thái đơn hàng
            order.setStatus("Cancel");

            // Lưu đơn hàng sau khi cập nhật
            orderRepository.save(order);

            // Trả về DTO sau khi cập nhật
            return convertToDTO(order);
        } catch (Exception e) {

            throw new RuntimeException(e);
        }
    }

    @Transactional
    public OrderDTO requestOrderCancellation(int orderId) {
        try{
        // Lấy đơn hàng theo orderId
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));

        // Kiểm tra trạng thái hiện tại có thể yêu cầu hủy không
        if (!order.getStatus().equals("Request")) {
            throw new RuntimeException("Order status is not valid for cancellation request");
        }

        // Cập nhật trạng thái đơn hàng thành Cancel_Request
        order.setStatus("Cancel_Request");

        // Lưu đơn hàng sau khi cập nhật
        orderRepository.save(order);

        // Trả về DTO sau khi cập nhật
        return convertToDTO(order);
    }catch (Exception e){

        throw new RuntimeException(e);
        }
    }


    public Long getTotalOrder(){
        return orderRepository.countOrders();
    }
    public BigDecimal getTotalRevenueThisMonth() {
        return orderRepository.totalRevenueThisMonth();
    }

    public BigDecimal getTotalRevenueToday() {
        return orderRepository.totalRevenueToday();
    }

    public BigDecimal getTotalRevenueThisYear() {
        return orderRepository.totalRevenueThisYear();
    }
}

