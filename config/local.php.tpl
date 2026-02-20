<?php
$parameters = [
    'db_driver'       => 'pdo_mysql',
    'db_host'         => 'mysql',
    'db_port'         => '3306',
    'db_name'         => '${MYSQL_DATABASE}',
    'db_user'         => '${MYSQL_USER}',
    'db_password'     => '${MYSQL_PASSWORD}',
    'db_table_prefix' => null,
    'cache_adapter'   => 'redis',
    'redis' => [
        'dsn' => 'redis://:${REDIS_PASSWORD}@redis:6379',
        'options' => [
            'lazy'           => false,
            'persistent'     => 0,
            'timeout'        => 30,
            'read_timeout'   => 0,
            'retry_interval' => 0,
        ],
    ],
    'site_url'  => '${MAUTIC_URL}',
    'installed' => false,
];
