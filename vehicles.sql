CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `license` varchar(50) NOT NULL,
    `citizenid` varchar(50) NOT NULL,
    `vehicle` varchar(50) DEFAULT NULL,
    `hash` varchar(50) DEFAULT NULL,
    `mods` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    `plate` varchar(15) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `plate` (`plate`),
    KEY `citizenid` (`citizenid`),
    KEY `license` (`license`)
) ENGINE=InnoDB AUTO_INCREMENT=1;

ALTER TABLE `player_vehicles`
ADD UNIQUE INDEX UK_playervehicles_plate (plate);

ALTER TABLE `player_vehicles`
ADD CONSTRAINT FK_playervehicles_players FOREIGN KEY (citizenid)
REFERENCES `players` (citizenid) ON DELETE CASCADE ON UPDATE CASCADE;
