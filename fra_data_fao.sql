-- Data source: https://fra-data.fao.org/assessments/fra/2020

-- View all top 200 data

SELECT TOP 200 *
FROM nature_db.dbo.Sheet1$

SELECT TOP 200 *
FROM nature_db.dbo.annual$

-- Regions don't just contain continents. Regions will be extracted into continents using the local temporary table
-- North and Central America, Africa, Europe, Asia, Oceania, South America

DROP TABLE IF EXISTS dbo.#TempContinent 
GO
SELECT DISTINCT iso3,
CASE 
    WHEN CHARINDEX('Africa', regions) <> 0 THEN 'Africa'
    WHEN CHARINDEX('Europe', regions) <> 0 THEN 'Europe'
    WHEN CHARINDEX('Oceania', regions) <> 0 THEN 'Oceania'
    WHEN CHARINDEX('Asia', regions) <> 0 THEN 'Asia'
    WHEN CHARINDEX('South America', regions) <> 0 THEN 'South America'
    WHEN CHARINDEX('North and Central America', regions) <> 0 THEN 'North and Central America'
END as continent
INTO dbo.#TempContinent
FROM nature_db.dbo.Sheet1$

-- Percentage of forest type classification

SELECT cont.continent, tbl.iso3, name, year, boreal, temperate, tropical, subtropical
FROM nature_db.dbo.Sheet1$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE tbl.[1a_forestArea] IS NOT NULL

-- From the initial observation of the table, the percentage of forest types is always repeated for every year (year)
-- It will be checked whether there are different percentages for different years in each country (name)

WITH unik AS
(SELECT name, COUNT(DISTINCT boreal) n_boreal, COUNT(DISTINCT temperate) n_temperate, COUNT(DISTINCT tropical) n_tropical, COUNT(DISTINCT subtropical) n_subtropical
FROM nature_db.dbo.Sheet1$ tbl
GROUP BY name
)
SELECT COUNT(DISTINCT n_boreal) , COUNT(DISTINCT n_temperate) , COUNT(DISTINCT n_tropical) , COUNT(DISTINCT n_subtropical) 
FROM unik

-- Because there is no value greater than 1, it shows that the percentage of forest type classifications is repeated for each year.
-- Percentage of forest type classification (data cleaning)

SELECT cont.continent, name, boreal, temperate, tropical, subtropical
FROM nature_db.dbo.Sheet1$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE tbl.[1a_forestArea] IS NOT NULL
GROUP BY cont.continent, name, boreal, temperate, tropical, subtropical

-- 1 Forest extent, characteristics and changes
-- 1a Extent of forest and other wooded land

SELECT cont.continent, name, year, tbl.[1a_forestArea], tbl.[1a_landArea], tbl.[1a_otherWoodedLand]
FROM nature_db.dbo.Sheet1$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE tbl.[1a_forestArea] IS NOT NULL OR tbl.[1a_landArea] IS NOT NULL OR tbl.[1a_otherWoodedLand] IS NOT NULL
ORDER BY name, year

--Will check whether land_area changes occur for each country

SELECT name, MAX(tbl.[1a_landArea]) - MIN(tbl.[1a_landArea])
FROM nature_db.dbo.Sheet1$ tbl
GROUP BY name
HAVING MAX(tbl.[1a_landArea]) - MIN(tbl.[1a_landArea]) <> 0

-- There is no change in land_area for each country

-- Max - Min forest_area by year for each country

SELECT DISTINCT cont.continent, name, 
    ROUND(FIRST_VALUE(tbl.[1a_forestArea]) OVER (PARTITION BY name ORDER BY year DESC) - FIRST_VALUE(tbl.[1a_forestArea]) OVER (PARTITION BY name ORDER BY year), 2) AS forestArea_change
FROM nature_db.dbo.Sheet1$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE tbl.[1a_forestArea] IS NOT NULL
ORDER BY name

-- Max - Min otherWoodedLand by year for each country

SELECT DISTINCT cont.continent, name, 
    ROUND(FIRST_VALUE(tbl.[1a_otherWoodedLand]) OVER (PARTITION BY name ORDER BY year DESC) - FIRST_VALUE(tbl.[1a_otherWoodedLand]) OVER (PARTITION BY name ORDER BY year), 2) AS otherWoodedLand_change
FROM nature_db.dbo.Sheet1$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE tbl.[1a_otherWoodedLand] IS NOT NULL
ORDER BY name

-- 1b Forest characteristics

SELECT cont.continent, name, year,
    tbl.[1b_naturallyRegeneratingForest]*1000 AS "Naturally Regenerating Forest",
    tbl.[1b_plantedForest]*1000 AS "Planted Forest"
FROM nature_db.dbo.Sheet1$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE (tbl.[1b_naturallyRegeneratingForest] IS NOT NULL OR
    tbl.[1b_plantedForest] IS NOT NULL) AND
    (tbl.[year] = 1990 OR
    tbl.[year] = 2000 OR
    tbl.[year] = 2010 OR
    tbl.[year] = 2020)
ORDER BY name, year

-- 1c Primary forest and special forest categories

SELECT cont.continent, name, year, tbl.[1c_bamboos], tbl.[1c_mangroves], tbl.[1c_primary], tbl.[1c_rubber], tbl.[1c_tempUnstocked]
FROM nature_db.dbo.Sheet1$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE tbl.[1c_bamboos] IS NOT NULL OR
    tbl.[1c_mangroves] IS NOT NULL OR
    tbl.[1c_primary] IS NOT NULL OR
    tbl.[1c_rubber] IS NOT NULL OR
    tbl.[1c_tempUnstocked] IS NOT NULL
ORDER BY name, year

-- 1d Annual forest expansion, deforestation and net change
-- 1e Annual reforestation

SELECT cont.continent, name, year, tbl.[1d_afforestation], tbl.[1d_deforestation], tbl.[1d_expansion], tbl.[1d_nat_exp], tbl.[1e_reforestation]
FROM nature_db.dbo.annual$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE tbl.[1d_afforestation] IS NOT NULL OR
    tbl.[1d_deforestation] IS NOT NULL OR
    tbl.[1d_expansion] IS NOT NULL OR
    tbl.[1d_nat_exp] IS NOT NULL OR
    tbl.[1e_reforestation] IS NOT NULL
ORDER BY name, year

-- 1b Forest characteristics join 1f Other land with tree cover

SELECT COALESCE(t1.continent, t2.continent) AS continent,
    COALESCE(t1.name, t2.name) AS name,
    COALESCE(t1.year, t2.year) AS year,
    t1.[Naturally Regenerating Forest], t1.[Planted Forest], t2.Agroforestry,
    t2.Palms, t2.[Tree Orchards], t2.[Trees in Urban Settings], t2.Other
FROM
(SELECT cont.continent, name, year,
    tbl.[1b_naturallyRegeneratingForest]*1000 AS "Naturally Regenerating Forest",
    tbl.[1b_plantedForest]*1000 AS "Planted Forest"
FROM nature_db.dbo.Sheet1$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE (tbl.[1b_naturallyRegeneratingForest] IS NOT NULL OR
    tbl.[1b_plantedForest] IS NOT NULL) AND
    (tbl.[year] = 1990 OR
    tbl.[year] = 2000 OR
    tbl.[year] = 2010 OR
    tbl.[year] = 2020)
) AS t1
FULL JOIN
(SELECT cont.continent, name, year,
    CAST(REPLACE(tbl.[1f_agroforestry], ',', '.') AS float)*1000 AS Agroforestry,
    CAST(REPLACE(tbl.[1f_other], ',', '.') AS float)*1000 AS Other,
    CAST(REPLACE(tbl.[1f_palms], ',', '.') AS float)*1000 AS Palms,
    CAST(REPLACE(tbl.[1f_treeOrchards], ',', '.') AS float)*1000 AS "Tree Orchards",
    CAST(REPLACE(tbl.[1f_treesUrbanSettings], ',', '.') AS float) *1000 AS "Trees in Urban Settings"
FROM nature_db.dbo.Sheet1$ tbl
LEFT JOIN dbo.#TempContinent cont
ON tbl.iso3 = cont.iso3
WHERE (tbl.[1f_agroforestry] IS NOT NULL OR
    tbl.[1f_other] IS NOT NULL OR
    tbl.[1f_palms] IS NOT NULL OR
    tbl.[1f_treeOrchards] IS NOT NULL OR
    tbl.[1f_treesUrbanSettings] IS NOT NULL) AND
    (tbl.[year] = 1990 OR
    tbl.[year] = 2000 OR
    tbl.[year] = 2010 OR
    tbl.[year] = 2020)
) AS t2
ON t1.name = t2.name AND t1.year = t2.year
