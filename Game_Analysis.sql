use game_analysis;

RENAME TABLE player_details TO pd;
RENAME TABLE level_details2 TO ld;

-- Problem Statement - Game Analysis dataset
-- 1) Players play a game divided into 3-levels (L0,L1 and L2)
-- 2) Each level has 3 difficulty levels (Low,Medium,High)
-- 3) At each level,players have to kill the opponents using guns/physical fight
-- 4) Each level has multiple stages at each difficulty level.
-- 5) A player can only play L1 using its system generated L1_code.
-- 6) Only players who have played Level1 can possibly play Level2 
--    using its system generated L2_code.
-- 7) By default a player can play L0.
-- 8) Each player can login to the game using a Dev_ID.
-- 9) Players can earn extra lives at each stage in a level.

alter table pd modify L1_Status varchar(30);
alter table pd modify L2_Status varchar(30);
alter table pd modify P_ID int primary key;
alter table pd drop myunknowncolumn;

alter table ld drop myunknowncolumn;
alter table ld change timestamp start_datetime datetime;
alter table ld modify Dev_Id varchar(10);
alter table ld modify Difficulty varchar(15);
alter table ld add primary key(P_ID,Dev_id,start_datetime);

-- pd (P_ID,PName,L1_status,L2_Status,L1_code,L2_Code)
-- ld (P_ID,Dev_ID,start_time,stages_crossed,level,difficulty,kill_count,
-- headshots_count,score,lives_earned)


-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players 
-- at level 0
SELECT pd.P_ID, ld.Dev_ID, pd.PName, ld.Difficulty
FROM pd
JOIN ld
ON pd.P_ID = ld.P_ID
WHERE ld.level = 0;


-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast
--    3 stages are crossed
SELECT pd.L1_Code, AVG(ld.Kill_Count) AS Avg_Kill_Count
FROM pd
JOIN ld
ON pd.P_ID = ld.P_ID
WHERE ld.Lives_Earned = 2 AND ld.Stages_Crossed >= 3
Group BY pd.L1_Code;


-- Q3) Find the total number of stages crossed at each diffuculty level
-- where for Level2 with players use zm_series devices. Arrange the result
-- in decsreasing order of total number of stages crossed.
SELECT Difficulty AS Difficulty_Level, COUNT(Stages_Crossed) AS Total_Stages_Crossed
FROM ld
WHERE Level = 2 AND Dev_Id LIKE 'zm%'
GROUP BY Difficulty_Level
ORDER BY Total_Stages_Crossed DESC;


-- Q4) Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.
SELECT P_ID, COUNT(DISTINCT(Start_datetime)) AS Unique_Dates
FROM ld
GROUP BY P_ID
HAVING COUNT(DISTINCT(Start_datetime)) > 1
ORDER BY Unique_Dates DESC;


-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.
SELECT P_ID, Level, SUM(Kill_Count) AS Total_Kill_Counts, AVG(Kill_Count) AS Avg_Kill_Count
FROM ld
WHERE Difficulty = 'Medium'
GROUP BY P_ID, Level
HAVING Total_Kill_Counts > Avg_Kill_Count
ORDER BY Level DESC;


-- Q6)  Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in asecending order of level.
SELECT ld.Level, SUM(ld.Lives_Earned) OVER (ORDER BY ld.Level) AS Total_Lives, pd.L1_Code, pd.L2_Code
FROM ld
JOIN pd
ON ld.P_ID = pd.P_ID
WHERE ld.Level <> 0;


-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well. 
WITH Ranked_Scores AS (
    SELECT Dev_Id, Score, Difficulty,
        ROW_NUMBER() OVER (PARTITION BY Dev_Id ORDER BY Score DESC) AS Ranks
    FROM ld
)
SELECT Dev_Id, Score, Difficulty, Ranks
FROM Ranked_Scores
WHERE Ranks <= 3
ORDER BY Dev_Id, Ranks;


-- Q8) Find first_login datetime for each device id
SELECT Dev_ID, MIN(Start_datetime) AS First_Login_Datetime
FROM ld
GROUP BY Dev_ID;


-- Q9) Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.
WITH Ranked_Scores AS (
    SELECT Dev_Id, Score, Difficulty,
        RANK() OVER (PARTITION BY Difficulty ORDER BY Score DESC) AS Ranks
    FROM ld
)
SELECT Dev_Id, Score, Difficulty, Ranks
FROM Ranked_Scores
WHERE Ranks <= 5
ORDER BY Difficulty, Ranks;


-- Q10) Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.
SELECT ld.P_Id, ld.Dev_Id, ld.Start_datetime AS First_Login_Datetime
FROM ld
INNER JOIN (
    SELECT P_Id, MIN(Start_datetime) AS Min_Start_Datetime
    FROM ld
    GROUP BY p_id
) AS Min_Start_Times
ON ld.P_Id = Min_Start_Times.P_Id AND ld.Start_datetime = Min_Start_Times.Min_Start_Datetime;


-- Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played -- by the player until that date.
-- a) window function
SELECT ld.P_ID, pd.PName, ld.Start_datetime,
    SUM(ld.Kill_Count) OVER (PARTITION BY ld.P_ID ORDER BY ld.Start_datetime) AS Games_Played_So_Far
FROM ld
JOIN pd
ON ld.P_ID = pd.P_ID;

-- b) without window function
SELECT ld.P_ID, pd.PName, ld.Start_datetime, SUM(ld2.Kill_Count) AS Games_Played_So_Far
FROM ld
JOIN pd
ON ld.P_ID = pd.P_ID 
JOIN ld AS ld2
ON ld.P_ID = ld2.P_ID AND ld2.Start_datetime <= ld.Start_datetime
GROUP BY ld.P_ID, ld.Start_datetime
ORDER BY ld.P_ID, ld.Start_datetime;


-- Q12) Find the cumulative sum of stages crossed over a start_datetime 
SELECT Start_datetime, SUM(Stages_crossed) OVER (ORDER BY Start_datetime) AS Cumulative_Sum_of_Stage_Crossed
FROM ld;


-- Q13) Find the cumulative sum of an stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime
WITH Ranked_Stages AS (
    SELECT P_ID, Start_datetime, Stages_crossed,
        ROW_NUMBER() OVER (PARTITION BY P_ID ORDER BY Start_datetime DESC) AS rn
    FROM ld
)
SELECT P_ID, Start_datetime, Stages_crossed,
    SUM(Stages_crossed) OVER (PARTITION BY P_ID ORDER BY Start_datetime) - Stages_crossed AS cumulative_sum
FROM Ranked_Stages
WHERE rn > 1;


-- Q14) Extract top 3 highest sum of score for each device id and the corresponding player_id
SELECT P_ID, Dev_Id, SUM(Score) AS Sum_of_Scores
FROM ld
GROUP BY P_ID, Dev_ID
ORDER BY Sum_of_Scores DESC
LIMIT 3;


-- Q15) Find players who scored more than 50% of the avg score scored by sum of 
-- scores for each player_id
SELECT ld.P_ID, pd.PName, SUM(ld.Score) AS Total_Scores, ROUND(AVG(ld.Score), 0) AS Avg_Scores
FROM ld
JOIN pd
ON ld.P_ID = pd.P_ID
GROUP BY P_ID
HAVING SUM(ld.Score) > 0.5 * ROUND(AVG(ld.Score), 0);


-- Q16) Create a stored procedure to find top n headshots_count based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.
DROP PROCEDURE IF EXISTS Get_Top_N_Headshots;

DELIMITER //
CREATE PROCEDURE Get_Top_N_Headshots(IN n INT)
BEGIN
    SELECT Dev_ID, Headshots_Count, Difficulty,
           ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY Headshots_Count DESC) AS `Rank`
    FROM ld
    ORDER BY Dev_ID, `Rank`
    LIMIT n;
END //
DELIMITER ;

CALL Get_Top_N_Headshots(15);


-- Q17) Create a function to return sum of Score for a given player_id.
DROP FUNCTION IF EXISTS Get_Total_Score_For_Player;

DELIMITER //
CREATE FUNCTION Get_Total_Score_For_Player(player_id INT) RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total_score INT;
    
    SELECT SUM(Score) INTO total_score
    FROM ld
    WHERE P_ID = player_id;
    
    RETURN total_score;
END//
DELIMITER ;

SELECT Get_Total_Score_For_Player(211) as Total_Score;
