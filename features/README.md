# Cơ chế tùy chọn

Các thư mục inventory, stamina, objectives, checkpoints, puzzles và security chứa cơ chế có thể dùng lại. Map tự chọn scene/node nào cần instance và cấu hình dữ liệu riêng.

Các lớp vẫn được biên dịch/đóng gói cùng project vì scene/script chung có thể tham chiếu chúng; chưa hỗ trợ xóa tùy ý một feature khỏi checkout. Các dữ liệu mặc định của bản thư viện được giữ để tương thích. Map mới cần đặt mục tiêu, vật phẩm và thông báo phù hợp với thiết kế của mình.

Logic chỉ dùng trong thư viện, như badge reader/dock/đường thoát đã biết, nằm trong `maps/library/scripts/`.
