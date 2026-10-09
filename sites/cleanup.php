<?php
// cleanup.php - removes legacy txt files and prunes old JSON logs
$baseDir = __DIR__;
$logDir = getenv('LOG_DIR') ?: $baseDir . '/logs';
$retentionDays = intval(getenv('LOG_RETENTION_DAYS') ?: 7);
$cutoff = strtotime("-{$retentionDays} days");

// Remove legacy files (ip.txt, usernames.txt) recursively
$it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($baseDir, FilesystemIterator::SKIP_DOTS));
foreach ($it as $file) {
    if ($file->isFile()) {
        $name = $file->getFilename();
        if ($name === 'ip.txt' || $name === 'usernames.txt') {
            @unlink($file->getPathname());
        }
    }
}

// Prune old JSON log files
if (is_dir($logDir)) {
    foreach (glob($logDir . '/*.json') as $jsonFile) {
        if (filemtime($jsonFile) < $cutoff) {
            @unlink($jsonFile);
        }
    }
}
?>
