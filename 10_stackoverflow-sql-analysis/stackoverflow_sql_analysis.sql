/*
====================================================
STACKOVERFLOW SQL ANALYSIS PROJECT
Автор: Татьяна Глушенко
====================================================

Описание:
Проект по анализу базы данных StackOverflow.

В ходе работы использованы:
- фильтрация данных;
- агрегирующие функции;
- JOIN;
- подзапросы;
- CTE;
- оконные функции;
- анализ временных рядов.

====================================================
ЧАСТЬ 1. SQL-ПРАКТИКА
====================================================
*/


-- Задача 1
-- Количество вопросов с рейтингом более 300
-- или минимум 100 добавлениями в избранное

SELECT COUNT(id)
FROM stackoverflow.posts
WHERE post_type_id IN (
    SELECT id
    FROM stackoverflow.post_types
    WHERE type = 'Question'
)
AND (
    score > 300
    OR favorites_count >= 100
);


-- Задача 2
-- Среднее количество вопросов в день
-- с 1 по 18 ноября 2008 года

WITH daily_questions AS (
    SELECT
        creation_date::date AS question_date,
        COUNT(id) AS questions_count
    FROM stackoverflow.posts
    WHERE post_type_id IN (
        SELECT id
        FROM stackoverflow.post_types
        WHERE type = 'Question'
    )
    AND creation_date::date
        BETWEEN '2008-11-01' AND '2008-11-18'
    GROUP BY 1
)

SELECT ROUND(AVG(questions_count))
FROM daily_questions;


-- Задача 3
-- Пользователи, получившие значок
-- в день регистрации

SELECT COUNT(DISTINCT u.id)
FROM stackoverflow.users u
JOIN stackoverflow.badges b
    ON u.id = b.user_id
WHERE b.creation_date::date = u.creation_date::date;


-- Задача 4
-- Количество уникальных постов Joel Coehoorn,
-- получивших хотя бы один голос

SELECT COUNT(DISTINCT p.id)
FROM stackoverflow.posts p
JOIN stackoverflow.users u
    ON u.id = p.user_id
JOIN stackoverflow.votes v
    ON v.post_id = p.id
WHERE u.display_name = 'Joel Coehoorn';


-- Задача 5
-- Ранжирование типов голосов
-- в обратном порядке

SELECT *,
       ROW_NUMBER() OVER (ORDER BY id DESC) AS rank
FROM stackoverflow.vote_types
ORDER BY id;


-- Задача 6
-- Топ-10 пользователей по количеству
-- голосов типа Close

SELECT
    user_id,
    COUNT(post_id) AS close_votes_count
FROM stackoverflow.votes
WHERE vote_type_id IN (
    SELECT id
    FROM stackoverflow.vote_types
    WHERE name = 'Close'
)
GROUP BY user_id
ORDER BY close_votes_count DESC,
         user_id DESC
LIMIT 10;


-- Задача 7
-- Топ пользователей по количеству значков

WITH badges_count AS (
    SELECT
        user_id,
        COUNT(id) AS badges_total
    FROM stackoverflow.badges
    WHERE creation_date::date
        BETWEEN '2008-11-15' AND '2008-12-15'
    GROUP BY user_id
)

SELECT
    user_id,
    badges_total,
    DENSE_RANK() OVER (
        ORDER BY badges_total DESC
    ) AS rank
FROM badges_count
ORDER BY badges_total DESC,
         user_id
LIMIT 10;


-- Задача 8
-- Средний рейтинг постов пользователя

SELECT
    title,
    user_id,
    score,
    ROUND(
        AVG(score)
        OVER (PARTITION BY user_id)
    ) AS avg_user_score
FROM stackoverflow.posts
WHERE title IS NOT NULL
  AND score <> 0;


-- Задача 9
-- Заголовки постов пользователей,
-- получивших более 1000 значков

WITH active_users AS (
    SELECT user_id
    FROM stackoverflow.badges
    GROUP BY user_id
    HAVING COUNT(id) > 1000
)

SELECT title
FROM stackoverflow.posts
WHERE title IS NOT NULL
  AND user_id IN (
      SELECT user_id
      FROM active_users
  );


-- Задача 10
-- Сегментация пользователей Канады
-- по количеству просмотров профиля

SELECT
    id,
    views,
    CASE
        WHEN views >= 350 THEN 1
        WHEN views BETWEEN 100 AND 349 THEN 2
        ELSE 3
    END AS user_group
FROM stackoverflow.users
WHERE location LIKE '%Canada%'
  AND views > 0;


-- Задача 11
-- Лидеры внутри каждой группы

WITH canada_users AS (
    SELECT
        id,
        views,
        CASE
            WHEN views >= 350 THEN 1
            WHEN views BETWEEN 100 AND 349 THEN 2
            ELSE 3
        END AS user_group
    FROM stackoverflow.users
    WHERE location LIKE '%Canada%'
      AND views > 0
),
group_max AS (
    SELECT
        id,
        user_group,
        views,
        MAX(views)
            OVER (PARTITION BY user_group)
            AS max_views
    FROM canada_users
)

SELECT
    id,
    user_group,
    views
FROM group_max
WHERE views = max_views
ORDER BY views DESC,
         id;


/*
====================================================
ЧАСТЬ 2. АНАЛИТИЧЕСКИЕ ЗАДАЧИ
====================================================
*/


-- Задача 1
-- Сумма просмотров постов по месяцам 2008 года

SELECT
    DATE_TRUNC('month', creation_date)::date AS month,
    SUM(views_count) AS total_views
FROM stackoverflow.posts
WHERE EXTRACT(YEAR FROM creation_date) = 2008
GROUP BY month
ORDER BY total_views DESC;


-- Задача 2
-- Самые активные пользователи
-- в первый месяц после регистрации

WITH active_users AS (
    SELECT u.display_name
    FROM stackoverflow.posts p
    JOIN stackoverflow.users u
        ON u.id = p.user_id
    WHERE p.post_type_id = 2
      AND p.creation_date::date
          BETWEEN u.creation_date::date
          AND u.creation_date::date + INTERVAL '1 month'
    GROUP BY u.display_name
    HAVING COUNT(*) > 100
)

SELECT
    display_name,
    COUNT(DISTINCT p.user_id)
FROM stackoverflow.users u
LEFT JOIN stackoverflow.posts p
    ON u.id = p.user_id
WHERE display_name IN (
    SELECT display_name
    FROM active_users
)
AND p.post_type_id = 2
AND p.creation_date::date
    BETWEEN u.creation_date::date
AND u.creation_date::date + INTERVAL '1 month'

GROUP BY display_name
ORDER BY display_name;


-- Задача 3
-- Количество постов по месяцам за 2008 год
-- для пользователей, зарегистрированных
-- в сентябре 2008 года и опубликовавших
-- хотя бы один пост в декабре

WITH selected_users AS (
    SELECT DISTINCT user_id
    FROM stackoverflow.users u
    JOIN stackoverflow.posts p
        ON p.user_id = u.id
    WHERE u.creation_date::date
          BETWEEN '2008-09-01' AND '2008-09-30'
      AND p.creation_date::date
          BETWEEN '2008-12-01' AND '2008-12-31'
)

SELECT
    DATE_TRUNC('month', p.creation_date)::date AS month,
    COUNT(p.id) AS posts_count
FROM stackoverflow.posts p
JOIN selected_users su
    USING (user_id)
WHERE p.creation_date::date
      BETWEEN '2008-01-01' AND '2008-12-31'
GROUP BY month
ORDER BY month DESC;


-- Задача 4
-- Накопительная сумма просмотров постов
-- для каждого пользователя

SELECT
    user_id,
    creation_date,
    views_count,
    SUM(views_count)
        OVER (
            PARTITION BY user_id
            ORDER BY creation_date, id
        ) AS cumulative_views
FROM stackoverflow.posts
ORDER BY user_id,
         creation_date;


-- Задача 5
-- Среднее количество активных дней пользователя
-- за период с 1 по 7 декабря 2008 года

WITH active_days AS (
    SELECT
        user_id,
        COUNT(DISTINCT creation_date::date) AS active_days_count
    FROM stackoverflow.posts
    WHERE creation_date
          BETWEEN '2008-12-01'
          AND '2008-12-07'
    GROUP BY user_id
)

SELECT ROUND(AVG(active_days_count))
FROM active_days;


-- Задача 6
-- Изменение количества постов
-- относительно предыдущего месяца

WITH monthly_posts AS (
    SELECT
        EXTRACT(MONTH FROM creation_date) AS month_num,
        COUNT(id) AS posts_count
    FROM stackoverflow.posts
    WHERE creation_date
          BETWEEN '2008-09-01'
          AND '2008-12-31'
    GROUP BY month_num
)

SELECT
    month_num,
    posts_count,
    ROUND(
        (
            posts_count
            - LAG(posts_count)
                OVER (ORDER BY month_num)
        )::numeric
        /
        LAG(posts_count)
            OVER (ORDER BY month_num)
        * 100,
        2
    ) AS growth_percent
FROM monthly_posts;


-- Задача 7
-- Пользователь с максимальным количеством постов
-- и его активность в октябре 2008 года

WITH most_active_user AS (
    SELECT
        user_id,
        COUNT(id) AS posts_count
    FROM stackoverflow.posts
    GROUP BY user_id
    ORDER BY posts_count DESC
    LIMIT 1
)

SELECT
    EXTRACT(WEEK FROM creation_date) AS week_number,
    MAX(creation_date) AS last_post_datetime
FROM stackoverflow.posts p
JOIN most_active_user m
    USING (user_id)
WHERE creation_date >= '2008-10-01'
  AND creation_date < '2008-11-01'
GROUP BY week_number
ORDER BY week_number;