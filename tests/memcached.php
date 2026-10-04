<?php
// Run with: php -n -d extension=/opt/bitnami/php/lib/php/extensions/memcached.so tests/memcached.php HOST
if (!extension_loaded('memcached') || !defined('Memcached::OPT_CLIENT_MODE')) {
    throw new RuntimeException('AWS Memcached extension missing');
}
$client = new Memcached();
$client->setOption(Memcached::OPT_CLIENT_MODE, Memcached::DYNAMIC_CLIENT_MODE);
if ($client->getOption(Memcached::OPT_CLIENT_MODE) !== Memcached::DYNAMIC_CLIENT_MODE) {
    throw new RuntimeException('ElastiCache client mode unavailable');
}
$client->setOption(Memcached::OPT_CLIENT_MODE, Memcached::STATIC_CLIENT_MODE);
$client->addServer($argv[1] ?? '127.0.0.1', 11211);
$key = 'bitcompat-ci-' . bin2hex(random_bytes(8));
$value = ['message' => 'Bitcompat', 'count' => 42];
try {
    if (!$client->set($key, $value, 30) || $client->get($key) !== $value) {
        throw new RuntimeException('Memcached round trip failed: ' . $client->getResultMessage());
    }
} finally {
    $client->delete($key);
}
echo PHP_VERSION, " AWS client mode and Memcached round trip OK\n";
