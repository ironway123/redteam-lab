<?php
// Deliberately vulnerable: unsanitized host param passed to shell.
$host = $_GET['host'] ?? '127.0.0.1';
echo "<pre>";
system("ping -c1 " . $host);
echo "</pre>";
