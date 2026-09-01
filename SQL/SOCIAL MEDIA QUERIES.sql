USE ig_clone;

-- OBJECTIVES QUESTIONS 

-- -1-
-- CHecking for DUPLICATE values in the users table
SELECT username, COUNT(*)
FROM users
GROUP BY username
HAVING COUNT(*) > 1;

--  Checking for NULL values in the users table
SELECT *
FROM users
WHERE username IS NULL;

-- -2- What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?

SELECT u.id AS user_id, u.username,
       COUNT(DISTINCT p.id) AS num_posts,
       COUNT(DISTINCT l.photo_id) AS num_likes,
       COUNT(DISTINCT c.id) AS num_comments
FROM users u
LEFT JOIN photos p ON u.id = p.user_id
LEFT JOIN likes l ON u.id = l.user_id
LEFT JOIN comments c ON u.id = c.user_id
GROUP BY u.id, u.username;

-- -3- Calculate the average number of tags per post (photo_tags and photos tables).

SELECT AVG(tags) AS avg_tags_per_post
FROM (SELECT p.id,COUNT(t.tag_id) AS tags
FROM photos p
LEFT JOIN photo_tags t ON p.id = t.photo_id GROUP BY p.id) AS num_tags;

-- -4- Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.

select u.id, u.username,
coalesce(l.total_likes,0) as total_likes,
coalesce(c.total_comments,0) as total_comments,
(coalesce(l.total_likes, 0) + coalesce(c.total_comments, 0)) as total_engagements,
rank() over(order by (coalesce(l.total_likes,0) + coalesce(c.total_comments,0)) desc ) as engagement_rankings
from users u 
left join ( select user_id,count(*) as total_likes from likes group by user_id) l on u.id=l.user_id
left join ( select user_id, count(*) as total_comments from comments group by user_id) c on u.id=c.user_id
order by engagement_rankings;

-- -5-Which users have the highest number of followers and followings?

with cte1 as ( select followee_id, count(follower_id) as followers_count from follows group by followee_id),
cte2 as  (select follower_id, count(followee_id) as followings_count from follows group by follower_id)
select  u.id, u.username,
 coalesce(cte1.followers_count,0)as followers_count,
 coalesce(cte2.followings_count,0) as followings_count
 from users u
 left join cte1 on u.id=cte1.followee_id
 left join cte2 on u.id=cte2.follower_id 
 order by followers_count desc, followings_count desc;
 
-- -6-  Calculate the average engagement rate (likes, comments) per post for each user.

SELECT 
u.id as user_id,
u.username,
COALESCE(p.num_posts, 0) AS num_posts,
COALESCE(l.num_likes, 0) AS num_likes,
COALESCE(c.num_comments, 0) AS num_comments,
CASE WHEN COALESCE(p.num_posts, 0) = 0 THEN 0
ELSE (COALESCE(l.num_likes, 0) + COALESCE(c.num_comments, 0)) / COALESCE(p.num_posts, 0)
END AS avg_engagement_rate
FROM users u
LEFT JOIN (SELECT user_id, COUNT(*) AS num_posts FROM photos
     GROUP BY user_id) p ON u.id = p.user_id
LEFT JOIN (SELECT user_id, COUNT(*) AS num_likes
     FROM likes
     GROUP BY user_id) l ON u.id = l.user_id
LEFT JOIN (SELECT user_id, COUNT(*) AS num_comments FROM comments GROUP BY user_id) c ON u.id = c.user_id
	ORDER BY avg_engagement_rate DESC;
    
-- -7-  Get the list of users who have never liked any post (users and likes tables)

SELECT
u.id,u.username
FROM users u
LEFT JOIN likes l ON u.id = l.user_id
WHERE l.user_id IS NULL;
    
-- 10--Calculate the total number of likes, comments, and photo tags for each user.
    
SELECT 
u.id as id, u.username,
COALESCE(l.total_likes, 0) AS total_likes,
COALESCE(c.total_comments, 0) AS total_comments,
COALESCE(pt.total_photo_tags, 0) AS total_photo_tags
FROM users u
LEFT JOIN (SELECT user_id, COUNT(*) AS total_likes FROM likes GROUP BY user_id) l ON u.id = l.user_id
LEFT JOIN (SELECT user_id, COUNT(*) AS total_comments FROM comments GROUP BY user_id) c ON u.id = c.user_id
LEFT JOIN (SELECT tag_id, COUNT(*) AS total_photo_tags FROM photo_tags GROUP BY tag_id) pt ON u.id = pt.tag_id;
        
-- -11-Rank users based on their total engagement (likes, comments, shares) over a month.

WITH MonthlyEngagement AS (
    SELECT u.id AS user_id, u.username, 
	COALESCE(l.total_likes, 0) AS total_likes, 
	COALESCE(c.total_comments, 0) AS total_comments,
	(COALESCE(l.total_likes, 0) + COALESCE(c.total_comments, 0)) AS total_engagement
    FROM users u
    LEFT JOIN (
        SELECT user_id, COUNT(photo_id) AS total_likes
        FROM likes
        WHERE DATE(created_at) >= '2024-07-01' OR DATE(created_at) <= '2024-07-31'
        GROUP BY user_id) l ON u.id = l.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(id) AS total_comments
        FROM comments
        WHERE DATE(created_at) >= '2024-07-01' OR DATE(created_at) <= '2024-07-31'
        GROUP BY user_id) c ON u.id = c.user_id)
SELECT user_id, username, total_likes, total_comments, total_engagement, RANK() OVER (ORDER BY total_engagement DESC)
AS engagement_rank
FROM MonthlyEngagement
ORDER BY engagement_rank;

-- -12- Retrieve the hashtags that have been used in posts with the highest average number of likes.
         -- Use a CTE to calculate the average likes for each hashtag first.

WITH Hashtag_Likes AS (
    SELECT ht.tag_name, COUNT(l.photo_id) AS total_likes, COUNT(DISTINCT p.id) AS total_posts
    FROM tags ht
    JOIN photo_tags pt ON ht.id = pt.tag_id
    JOIN photos p ON pt.photo_id = p.id
    LEFT JOIN likes l ON p.id = l.photo_id
    GROUP BY ht.tag_name),
Average_Likes_Per_Hashtag AS (
    SELECT tag_name, (CAST(total_likes AS FLOAT) / total_posts) AS avg_likes
    FROM Hashtag_Likes)
SELECT tag_name, round(avg_likes,2) as avg_Likes
FROM Average_Likes_Per_Hashtag
order by avg_likes desc
limit 5;

-- -13- Retrieve the users who have started following someone after being followed by that person
    
     SELECT f1.follower_id, f1.followee_id
 FROM follows f1
 JOIN follows f2 ON f1.follower_id = f2.followee_id AND f1.followee_id = f2.follower_id
 WHERE f1.created_at > f2.created_at;
 

-- SUBJECTIVE  QUESTIONS 

-- -1- Based on user engagement and activity levels, which users would you consider the most loyal or valuable? 
		-- How would you reward or incentivize these users?

WITH TotalLikes AS (
    SELECT u.id, COUNT(distinct l.photo_id) AS total_likes
    FROM users u
    LEFT JOIN likes l ON u.id = l.user_id
    GROUP BY u.id),
TotalComments AS (
    SELECT u.id, COUNT(distinct c.photo_id) AS total_comments
    FROM users u
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY u.id),
PhotosPosted AS (
    SELECT user_id, COUNT(id) AS total_photos_posted
    FROM photos
    GROUP BY user_id),
Followers AS (
    SELECT followee_id AS user_id, COUNT(follower_id) AS total_followers
    FROM follows
    GROUP BY followee_id),
UniqueTags AS (
    SELECT p.user_id, COUNT(DISTINCT pt.tag_id) AS unique_tags_used
    FROM photos p
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    GROUP BY p.user_id)
SELECT u.id AS user_id, u.username,
    COALESCE(tl.total_likes, 0) AS total_likes,
    COALESCE(tc.total_comments, 0) AS total_comments,
    COALESCE(pp.total_photos_posted, 0) AS total_photos_posted,
    COALESCE(f.total_followers, 0) AS total_followers,
    COALESCE(ut.unique_tags_used, 0) AS unique_tags_used,
    (COALESCE(tl.total_likes, 0) + COALESCE(tc.total_comments, 0)) AS total_engagement
FROM users u
LEFT JOIN TotalLikes tl ON u.id = tl.id
LEFT JOIN TotalComments tc ON u.id = tc.id
LEFT JOIN PhotosPosted pp ON u.id = pp.user_id
LEFT JOIN Followers f ON u.id = f.user_id
LEFT JOIN UniqueTags ut ON u.id = ut.user_id
group by u.id 
having total_photos_posted >0
ORDER BY total_engagement DESC, total_followers DESC, total_photos_posted DESC
limit 10;

-- -3- Which hashtags or content topics have the highest engagement rates? 
        -- How can this information guide content strategy and ad campaigns?

WITH PhotoEngagement AS (
    SELECT
        p.id AS photo_id,
        COUNT(distinct l.photo_id) AS total_likes,
        COUNT(DISTINCT c.id) AS total_comments,
        COUNT(distinct l.photo_id) + COUNT(DISTINCT c.user_id) AS total_engagement
    FROM photos p
    LEFT JOIN likes l ON p.user_id = l.user_id
    LEFT JOIN comments c ON p.user_id = c.user_id
    GROUP BY p.id),
HashtagEngagement AS (
    SELECT
        t.id AS tag_id,
        t.tag_name,
        count(pe.total_engagement) AS total_engagement,
        COUNT(DISTINCT pt.photo_id) AS total_photos,
        (count(pe.total_engagement) / COUNT(DISTINCT pt.photo_id) )AS engagement_rate
    FROM tags t
    JOIN photo_tags pt ON t.id = pt.tag_id
    JOIN PhotoEngagement pe ON pt.photo_id = pe.photo_id
    GROUP BY t.id, t.tag_name)
SELECT tag_name, total_photos, total_engagement, engagement_rate
FROM HashtagEngagement
ORDER BY total_engagement DESC
limit 10;

-- -4- Are there any patterns or trends in user engagement based on demographics (age, location, gender) 
		-- or posting times? How can these insights inform targeted marketing campaigns?

SELECT 
    HOUR(p.created_dat) AS post_hour,
    DAYOFWEEK(p.created_dat) AS post_day,
    COUNT(DISTINCT p.id) AS total_photos_posted,
    COUNT(DISTINCT l.photo_id) AS total_likes_received,
    COUNT(DISTINCT c.id) AS total_comments_made
FROM photos p
 JOIN likes l ON p.id = l.photo_id
 JOIN comments c ON p.id = c.photo_id
GROUP BY post_hour, post_day
ORDER BY post_hour, post_day;

-- -5- Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns? 
        -- How would you approach and collaborate with these influencers?

WITH TotalLikes AS (
    SELECT u.id, COUNT(distinct l.photo_id) AS total_likes
    FROM users u
    LEFT JOIN likes l ON u.id = l.user_id
    GROUP BY u.id),
TotalComments AS (
    SELECT u.id, COUNT(distinct c.photo_id) AS total_comments
    FROM users u
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY u.id),
PhotosPosted AS (
    SELECT user_id, COUNT(id) AS total_photos_posted
    FROM photos
    GROUP BY user_id),
Followers AS (
    SELECT followee_id AS user_id, COUNT(follower_id) AS total_followers
    FROM follows
    GROUP BY followee_id)
SELECT u.id AS user_id, u.username,
    COALESCE(tl.total_likes, 0) AS total_likes,
    COALESCE(tc.total_comments, 0) AS total_comments,
    COALESCE(pp.total_photos_posted, 0) AS total_photos_posted,
    COALESCE(f.total_followers, 0) AS total_followers,
    ((COALESCE(tl.total_likes, 0) + COALESCE(tc.total_comments, 0))/(COALESCE(pp.total_photos_posted, 0)))  as engagement_rate
FROM users u
JOIN TotalLikes tl ON u.id = tl.id
JOIN TotalComments tc ON u.id = tc.id
JOIN PhotosPosted pp ON u.id = pp.user_id
JOIN Followers f ON u.id = f.user_id
group by u.id 
having total_photos_posted >0
ORDER BY  engagement_rate desc, total_followers desc,total_photos_posted desc 
limit 10;

-- -6-Based on user behavior and engagement data, 
	   -- how would you segment the user base for targeted marketing campaigns or personalized recommendations?

SELECT 
    u.id AS user_id,
    u.username,
    COALESCE(p.total_posts, 0) AS total_posts,
    COALESCE(l.total_likes, 0) + COALESCE(c.total_comments, 0) AS total_engagement,
    CASE
	WHEN COALESCE(l.total_likes, 0) + COALESCE(c.total_comments, 0) > 150 THEN 'Highly Engaged'
	WHEN COALESCE(l.total_likes, 0) + COALESCE(c.total_comments, 0) BETWEEN 100 AND 150 THEN 'Moderately Engaged'
	ELSE 'Less Engaged' END AS user_category,
    CASE 
	WHEN YEAR(u.created_at) >= 2017 THEN 'New_User'
	ELSE 'Old_User' END AS user_join_status
FROM users u
LEFT JOIN (
    SELECT user_id, COUNT(*) AS total_likes
    FROM ig_clone.likes
    GROUP BY user_id) l ON u.id = l.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS total_comments
    FROM comments
    GROUP BY user_id) c ON u.id = c.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS total_posts
    FROM photos
    GROUP BY user_id) p ON u.id = p.user_id
GROUP BY u.id
HAVING total_posts > 0 
ORDER BY total_engagement DESC, user_category;


-- -10- Assuming there's a "User_Interactions" table tracking user engagements, 
         -- how can you update the "Engagement_Type" column to change all instances of
		-- "Like" to "Heart" to align with Instagram's terminology?

CREATE TABLE User_Interactions(
	id INT AUTO_INCREMENT UNIQUE PRIMARY KEY,
	username VARCHAR(250) NOT NULL,
	Engagement_Type varchar(250) not null);

INSERT INTO User_Interactions (username,Engagement_Type ) VALUES 
('Kenton_Kirlin', 'Like'),
 ('Andre_Purdy85', 'Comments'), 
 ('Harley_Lind18', 'Comments'),
 ('Arely_Bogan63', 'Comments'), 
 ('Aniya_Hackett', 'Like'), 
 ('Travon.Waters', 'Like'), 
 ('Kasandra_Homenick', 'Comments'), 
 ('Tabitha_Schamberger11', 'Comments'),
 ('Gus93', 'Like'), 
 ('Presley_McClure', 'Comments'), 
 ('Justina.Gaylord27', 'Like'), 
 ('Dereck65', 'Comments'), 
 ('Alexandro35', 'Comments'), 
 ('Jaclyn81', 'Comments'), 
 ('Billy52', 'Like'), 
 ('Annalise.McKenzie16', 'Comments'), 
 ('Norbert_Carroll35', 'Like'), 
 ('Odessa2', 'Comments'), 
 ('Hailee26', 'Comments'), 
 ('Delpha.Kihn', 'Like'), 
 ('Rocio33', 'Like'), 
 ('Kenneth64', 'Like'), 
 ('Eveline95', 'Like'),
 ('Maxwell.Halvorson', 'Like'), 
 ('Tierra.Trantow', 'Like'),
 ('Josianne.Friesen', 'Like'), 
 ('Darwin29', 'Like'), 
 ('Dario77', 'Like'),
 ('Jaime53', 'Comments'),
 ('Kaley9', 'Comments'), 
 ('Aiyana_Hoeger', 'Like'), 
 ('Irwin.Larson', 'Like'), 
 ('Yvette.Gottlieb91', 'Comments'), 
 ('Pearl7', 'Like'), 
 ('Lennie_Hartmann40', 'Comments'), 
 ('Ollie_Ledner37', 'Like'), 
 ('Yazmin_Mills95', 'Comments'), 
 ('Jordyn.Jacobson2', 'Like'), 
 ('Kelsi26', 'Like'), 
 ('Rafael.Hickle2', 'Comments'), 
 ('Mckenna17', 'Like'), 
 ('Maya.Farrell', 'Comments'), 
 ('Janet.Armstrong', 'Like'), 
 ('Seth46', 'Comments'), 
 ('David.Osinski47', 'Like'), 
 ('Malinda_Streich', 'Comments'), 
 ('Harrison.Beatty50', 'Like'), 
 ('Granville_Kutch', 'Comments'), 
 ('Morgan.Kassulke', 'Like'), 
 ('Gerard79', 'Comments'), 
 ('Mariano_Koch3', 'Comments'), 
 ('Zack_Kemmer93', 'Like'), 
 ('Linnea59', 'Comments'), 
 ('Duane60', 'Comments'), 
 ('Meggie_Doyle', 'Like'), 
 ('Peter.Stehr0', 'Comments'), 
 ('Julien_Schmidt', 'Like'), 
 ('Aurelie71', 'Comments'), 
 ('Cesar93', 'Comments'), 
 ('Sam52', 'Like'), 
 ('Jayson65', 'Comments'), 
 ('Ressie_Stanton46', 'Like'), 
 ('Elenor88', 'Comments'), 
 ('Florence99', 'Like'), 
 ('Adelle96', 'Comments'), 
 ('Mike.Auer39', 'Comments'), 
 ('Emilio_Bernier52', 'Like'), 
 ('Franco_Keebler64', 'Comments'), 
 ('Karley_Bosco', 'Like'), 
 ('Erick5', 'Comments'), 
 ('Nia_Haag', 'Like'), 
 ('Kathryn80', 'Comments'), 
 ('Jaylan.Lakin', 'Like'), 
 ('Hulda.Macejkovic', 'Comments'), 
 ('Leslie67', 'Comments'), 
 ('Janelle.Nikolaus81', 'Like'), 
 ('Donald.Fritsch', 'Comments'), 
 ('Colten.Harris76', 'Like'), 
 ('Katarina.Dibbert', 'Comments'), 
 ('Darby_Herzog', 'Comments'), 
 ('Esther.Zulauf61', 'Like'), 
 ('Aracely.Johnston98', 'Comments'), 
 ('Bartholome.Bernhard', 'Comments'), 
 ('Alysa22', 'Comments'), 
 ('Milford_Gleichner42', 'Like'), 
 ('Delfina_VonRueden68', 'Comments'), 
 ('Rick29', 'Like'), 
 ('Clint27', 'Comments'), 
 ('Jessyca_West', 'Comments'), 
 ('Esmeralda.Mraz57', 'Like'), 
 ('Bethany20', 'Comments'), 
 ('Frederik_Rice', 'Comments'), 
 ('Willie_Leuschke', 'Like'), 
 ('Damon35', 'Comments'), 
 ('Nicole71', 'Comments'), 
 ('Keenan.Schamberger60', 'Like'), 
 ('Tomas.Beatty93', 'Comments'), 
 ('Imani_Nicolas17', 'Like'), 
 ('Alek_Watsica', 'Comments'), 
 ('Javonte83', 'Like');
 
 SET SQL_SAFE_UPDATES = 0;
 update  User_Interactions 
 set  Engagement_Type = "Heart" 
 where Engagement_Type= "Like";
 
  select * from User_Interactions; 
 
