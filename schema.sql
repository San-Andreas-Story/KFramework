CREATE TABLE IF NOT EXISTS `kf_characters` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Correspond à Player.charId côté Lua.',
    `identifier` VARCHAR(60) NOT NULL COMMENT 'Identifiant persistant du joueur (license2, replié sur license).',
    `name`       VARCHAR(50) NOT NULL,
    `position`   JSON NULL COMMENT 'Sérialisé via json.encode côté Lua : {x, y, z, heading} (_Player:toDB).',
    `metadata`   JSON NULL COMMENT 'Sérialisé via json.encode côté Lua : table libre (_Player:toDB).',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_kf_characters_identifier` (`identifier`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Personnages des joueurs. Un personnage actif par identifiant (voir Server.Players).';