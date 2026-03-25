-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Mar 25, 2026 at 03:47 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `paquexpress_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `agentes`
--

CREATE TABLE `agentes` (
  `id_agente` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `correo` varchar(100) NOT NULL,
  `password` varchar(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `agentes`
--

INSERT INTO `agentes` (`id_agente`, `nombre`, `correo`, `password`) VALUES
(1, 'Arleth', 'arlethseg@gmail.com', 'e10adc3949ba59abbe56e057f20f883e'),
(2, 'Raúl', 'raul@gmail.com', 'e10adc3949ba59abbe56e057f20f883e');

-- --------------------------------------------------------

--
-- Table structure for table `entregas`
--

CREATE TABLE `entregas` (
  `id_entrega` int(11) NOT NULL,
  `id_agente` int(11) NOT NULL,
  `id_paquete` int(11) NOT NULL,
  `ruta_foto` varchar(255) NOT NULL,
  `latitud` varchar(50) NOT NULL,
  `longitud` varchar(50) NOT NULL,
  `direccion` varchar(255) DEFAULT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `entregas`
--

INSERT INTO `entregas` (`id_entrega`, `id_agente`, `id_paquete`, `ruta_foto`, `latitud`, `longitud`, `direccion`, `fecha`) VALUES
(1, 1, 2, 'uploads/scaled_paquete2.png', '20.540431934948636', '-100.39665421448007', 'Circuito Carranco, Colinas del Sol, Mision Mariana 2, Corregidora, Querétaro, 76906, México', '2026-03-25 10:28:36'),
(2, 1, 3, 'uploads/scaled_paquete.png', '20.655076217682733', '-100.40410747845516', 'No se pudo obtener dirección', '2026-03-25 20:17:43');

-- --------------------------------------------------------

--
-- Table structure for table `paquetes`
--

CREATE TABLE `paquetes` (
  `id_paquete` int(11) NOT NULL,
  `direccion_destino` varchar(255) NOT NULL,
  `estado` varchar(20) NOT NULL DEFAULT 'pendiente'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `paquetes`
--

INSERT INTO `paquetes` (`id_paquete`, `direccion_destino`, `estado`) VALUES
(1, 'UTEQ, av. Pie de la cuesta', 'pendiente'),
(2, 'Circuito carranco, Mision Candiles #260', 'entregado'),
(3, 'UTEQ', 'entregado');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `agentes`
--
ALTER TABLE `agentes`
  ADD PRIMARY KEY (`id_agente`),
  ADD UNIQUE KEY `correo` (`correo`);

--
-- Indexes for table `entregas`
--
ALTER TABLE `entregas`
  ADD PRIMARY KEY (`id_entrega`),
  ADD UNIQUE KEY `id_paquete` (`id_paquete`),
  ADD KEY `id_agente` (`id_agente`);

--
-- Indexes for table `paquetes`
--
ALTER TABLE `paquetes`
  ADD PRIMARY KEY (`id_paquete`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `agentes`
--
ALTER TABLE `agentes`
  MODIFY `id_agente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `entregas`
--
ALTER TABLE `entregas`
  MODIFY `id_entrega` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `paquetes`
--
ALTER TABLE `paquetes`
  MODIFY `id_paquete` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `entregas`
--
ALTER TABLE `entregas`
  ADD CONSTRAINT `entregas_ibfk_1` FOREIGN KEY (`id_agente`) REFERENCES `agentes` (`id_agente`),
  ADD CONSTRAINT `entregas_ibfk_2` FOREIGN KEY (`id_paquete`) REFERENCES `paquetes` (`id_paquete`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
