

--A)
SELECT AVG(table_rows) AS avg_records_per_table
FROM information_schema.tables
WHERE table_schema = 'ZooDB';
---
SELECT Name, Species
FROM Animals
WHERE Animal_ID IN (
    SELECT Animal_ID
    FROM Enclosures
    WHERE enclosure_type_id = (
        SELECT enclosure_type_id 
        FROM Enclosure_Types 
        WHERE enclosure_type = 'Aquatic'
    )
);
----
SELECT 
    Species,
    COUNT(*) AS Total_Animals
FROM 
    animals
GROUP BY 
    Species;

---
SELECT 
    a1.Animal_ID AS Animal_1_ID,
    a1.Name AS Animal_1_Name,
    a2.Animal_ID AS Animal_2_ID,
    a2.Name AS Animal_2_Name,
    a1.Species,
    YEAR(a1.Date_of_Birth) AS Birth_Year
FROM 
    animals a1
JOIN 
    animals a2 
    ON a1.Species = a2.Species 
    AND YEAR(a1.Date_of_Birth) = YEAR(a2.Date_of_Birth)
    AND a1.Animal_ID < a2.Animal_ID
ORDER BY 
    a1.Species, Birth_Year;


----------------------------------------------------




--B)
CREATE or REPLACE VIEW Animal_Enclosure_Info AS
SELECT 
    a.Name AS Animal_Name, 
    a.Species, 
    e.Name, 
    et.enclosure_type
FROM Animals a
INNER JOIN Enclosure_Animals ea ON a.Animal_ID = ea.Animal_ID
INNER JOIN Enclosures e ON ea.Enclosure_ID = e.Enclosure_ID
LEFT JOIN Enclosure_Types et ON e.Enclosure_Type_ID = et.Enclosure_Type_ID;

SELECT * FROM Animal_Enclosure_Info;
----------------------------------------------------------------------
CREATE or REPLACE VIEW Animal_Health_Records AS
SELECT 
    hr.Date AS Record_Date,
    hr.Description AS Record_Description,
    a.Name AS Animal_Name,
    COALESCE(d.Diagnosis_Name, 'No Diagnosis') AS Diagnosis,
    COALESCE(t.Treatment_Name, 'No Treatment') AS Treatment,
    CONCAT(v.Name, ' ', v.Surname) AS Veterinarian
FROM Health_Records hr
INNER JOIN Animals a ON hr.Animal_ID = a.Animal_ID
LEFT JOIN Health_Diagnoses d ON hr.Diagnosis_ID = d.Diagnosis_ID
LEFT JOIN Health_Treatments t ON hr.Treatment_ID = t.Treatment_ID
INNER JOIN Veterinarians v ON hr.Veterinarian_ID = v.Veterinarian_ID;


SELECT * FROM Animal_Health_Records;
------------------------------------------------------------------------
-- CREATE VIEW Animal_Health_Records AS
-- SELECT 
--     hr.Record_ID,
--     hr.Date AS Record_Date,
--     hr.Description AS Record_Description,
--     a.Name AS Animal_Name,
--     d.Diagnosis_Name AS Diagnosis,
--     t.Treatment_Name AS Treatment,
--     v.Name AS Veterinarian_Name,
--     v.Surname AS Veterinarian_Surname
-- FROM 
--     Health_Records hr
-- INNER JOIN 
--     Animals a ON hr.Animal_ID = a.Animal_ID
-- INNER JOIN 
--     Health_Diagnoses d ON hr.Diagnosis_ID = d.Diagnosis_ID
-- INNER JOIN 
--     Health_Treatments t ON hr.Treatment_ID = t.Treatment_ID
-- INNER JOIN 
--     Veterinarians v ON hr.Veterinarian_ID = v.Veterinarian_ID;
----------------------------------------------------------------------------------------------------




--C)
CREATE UNIQUE INDEX idx_animals_name ON Animals(Name);
INSERT INTO animals VALUES(NULL,"Kiara","Penguin","2025-02-06","Female","2025-02-06",0);
-----------
CREATE FULLTEXT INDEX idx_health_records_description ON Health_Records(Description);



--D)
DELIMITER //
CREATE OR REPLACE FUNCTION get_average_animal_age() 
RETURNS DECIMAL(5,2) DETERMINISTIC
BEGIN
    DECLARE avg_age DECIMAL(5,2);
    SELECT AVG(TIMESTAMPDIFF(YEAR, Date_of_Birth, CURDATE())) INTO avg_age FROM Animals;
    RETURN avg_age;
END //
DELIMITER ;

SELECT get_average_animal_age();

DELIMITER //

CREATE OR REPLACE FUNCTION get_average_age_by_species(species_name VARCHAR(50)) 
RETURNS DECIMAL(5,2) DETERMINISTIC
BEGIN
    DECLARE avg_age DECIMAL(5,2);

    SELECT AVG(TIMESTAMPDIFF(YEAR, Date_of_Birth, CURDATE())) 
    INTO avg_age 
    FROM Animals 
    WHERE Species = species_name;

    RETURN IFNULL(avg_age, 0); -- Vrátí 0, pokud druh neexistuje nebo nemá záznamy
END //

DELIMITER ;


SELECT get_average_age_by_species("Lion");





--E)

DELIMITER //
CREATE or REPLACE PROCEDURE CHECK_ANIMAL_AGE()
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE animals_id INT(11);
    DECLARE animal_age INT;

    
    DECLARE cur CURSOR FOR 
    SELECT Animal_ID, TIMESTAMPDIFF(YEAR, Date_of_Birth, CURDATE()) AS Age 
    FROM animals
    WHERE TIMESTAMPDIFF(YEAR, Date_of_Birth, CURDATE()) >= 10;


    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO animals_id, animal_age;
        -- SELECT animals_id, animal_age;
        IF done THEN 
            LEAVE read_loop;
        END IF;
        
        UPDATE animals 
        SET Needs_Checkup = 1 
        WHERE Animal_ID = animals_id;
    END LOOP;

    CLOSE cur;
END //
DELIMITER ;

CALL CHECK_ANIMAL_AGE();
----------------------------------------






--f)
CREATE TABLE IF NOT EXISTS Animal_Update_Log (
    Log_ID INT AUTO_INCREMENT PRIMARY KEY,
    Animal_ID INT NOT NULL,
    Old_Name VARCHAR(255),
    New_Name VARCHAR(255),
    Old_Species VARCHAR(255),
    New_Species VARCHAR(255),
    Update_Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Updated_By VARCHAR(255) 
);


DELIMITER //

CREATE or REPLACE TRIGGER log_animal_update
AFTER UPDATE ON Animals
FOR EACH ROW
BEGIN
    INSERT INTO Animal_Update_Log (Animal_ID, Old_Name, New_Name, Old_Species, New_Species, Updated_By)
    VALUES (
        OLD.Animal_ID, OLD.Name, NEW.Name, OLD.Species, NEW.Species, USER()
    );
END //

DELIMITER ;

UPDATE animals SET Name = "Adam" WHERE Animal_ID = 11;

UPDATE animals SET Name = "Alex" WHERE Animal_ID = 11;
-----------------------------------------------------------------------



--G)
DELIMITER //

CREATE OR REPLACE PROCEDURE CHECK_ANIMAL_AGE(In min_age INT)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE animals_id INT;
    DECLARE animal_age INT;
    DECLARE error_occurred INT DEFAULT 0;


    DECLARE cur CURSOR FOR 
    SELECT Animal_ID, TIMESTAMPDIFF(YEAR, Date_of_Birth, CURDATE()) 
    FROM animals
    WHERE TIMESTAMPDIFF(YEAR, Date_of_Birth, CURDATE()) >= min_age;



  
    DECLARE CONTINUE HANDLER FOR NOT FOUND 
    BEGIN
        SET done = 1;
    END;

   

   

  
    START TRANSACTION;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO animals_id, animal_age;
        
        SELECT CONCAT('Processing Animal ID: ', animals_id, ', Age: ', animal_age) AS Debug_Info;
        
        IF done THEN 
            LEAVE read_loop;
        END IF;

        UPDATE animals 
        SET Needs_Checkup = 1 
        WHERE Animal_ID = animals_id;
    END LOOP;

    CLOSE cur;
    IF done THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

    

END //

DELIMITER ;

UPDATE animals SET Need



--H
CREATE USER 'Adam'@'%' IDENTIFIED by "Adam";

  
GRANT SELECT, INSERT, UPDATE ON zoodb.* TO 'Adam'@'%';
GRANT LOCK TABLES ON zoodb.* TO 'Adam'@'%';

-- jit do D:\UJEP\programming\xampp\mysql\bin\mysql.exe
-- mysql.exe -u jmeno_uzivatele -p 
-- use zoodb
-- Locknout tabulku v cmd.exe
  
--    DELETE, CREATE, DROP, RELOAD, FILE, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, CREATE VIEW, EVENT, TRIGGER, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EXECUTE nikdy nepouzivat
   

----------------------------------------------------------------------------------------------------
   --
   LOCK TABLES 
    Health_Records WRITE, 
    Animals READ;
-------------
    UNLOCK TABLES;
--------------






