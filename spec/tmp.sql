-- With books_versions
-- through-assoc bug present
SELECT
  "authors_versions"."version_id" AS t0_r0,
  "authors_versions"."id" AS t0_r1,
  "authors_versions"."name" AS t0_r2,
  "authors_versions"."validity" AS t0_r3,
  "libraries_versions"."version_id" AS t1_r0,
  "libraries_versions"."id" AS t1_r1,
  "libraries_versions"."name" AS t1_r2,
  "libraries_versions"."validity" AS t1_r3
FROM "authors_versions"
LEFT OUTER JOIN "books_versions"
  ON "books_versions"."author_id" = "authors_versions"."id"
    AND ("books_versions"."validity" @> upper("authors_versions"."validity")
      OR (upper_inf("books_versions"."validity")
        AND upper_inf("authors_versions"."validity")))
LEFT OUTER JOIN "libraries_versions"
  ON "libraries_versions"."id" = "books_versions"."library_id"
    AND ("libraries_versions"."validity" @> upper("books_versions"."validity")
      OR (upper_inf("libraries_versions"."validity")
        AND upper_inf("books_versions"."validity")))
    AND ("libraries_versions"."validity" @> upper("authors_versions"."validity")
      OR (upper_inf("libraries_versions"."validity")
        AND upper_inf("authors_versions"."validity")))

-- With books_versions
-- through-assoc bug fixed
SELECT
  "authors_versions"."version_id" AS t0_r0, "authors_versions"
  "id" AS t0_r1, "authors_versions"
  "name" AS t0_r2, "authors_versions"
  "validity" AS t0_r3, "libraries_versions"
  "version_id" AS t1_r0, "libraries_versions"
  "id" AS t1_r1, "libraries_versions"
  "name" AS t1_r2, "libraries_versions"
  "validity" AS t1_r3
FROM "authors_versions"
LEFT OUTER JOIN "books_versions"
  ON "books_versions"."author_id" = "authors_versions"."id"
    AND ("books_versions"."validity" @> upper("authors_versions"."validity")
      OR (upper_inf("books_versions"."validity")
        AND upper_inf("authors_versions"."validity")))
LEFT OUTER JOIN "libraries_versions"
  ON "libraries_versions"."id" = "books_versions"."library_id"
    AND ("libraries_versions"."validity" @> upper("books_versions"."validity")
      OR (upper_inf("libraries_versions"."validity")
        AND upper_inf("books_versions"."validity")))

-- With books_versions, as of 2025-10-09 23:43:59.995448
-- through-assoc bug present
SELECT
  "authors_versions"."version_id" AS t0_r0,
  "authors_versions"."id" AS t0_r1,
  "authors_versions"."name" AS t0_r2,
  "authors_versions"."validity" AS t0_r3,
  "libraries_versions"."version_id" AS t1_r0,
  "libraries_versions"."id" AS t1_r1,
  "libraries_versions"."name" AS t1_r2,
  "libraries_versions"."validity" AS t1_r3
FROM "authors_versions"
LEFT OUTER JOIN "books_versions"
  ON "books_versions"."author_id" = "authors_versions"."id"
    AND "books_versions"."validity" @> CAST('2025-10-09 23:43:59.995448' AS timestamptz)
LEFT OUTER JOIN "libraries_versions"
  ON "libraries_versions"."id" = "books_versions"."library_id"
    AND "libraries_versions"."validity" @> CAST('2025-10-09 23:43:59.995448' AS timestamptz)
    AND "libraries_versions"."validity" @> CAST('2025-10-09 23:43:59.995448' AS timestamptz)
WHERE (authors_versions.validity @> '2025-10-09 23:43:59.995448'::timestamptz)

-- With books_versions, as of 2025-10-09 23:57:58.215137
-- through-assoc bug fixed
SELECT
  "authors_versions"."version_id" AS t0_r0, "authors_version
  "."id" AS t0_r1, "authors_version
  "."name" AS t0_r2, "authors_version
  "."validity" AS t0_r3, "libraries_version
  "."version_id" AS t1_r0, "libraries_version
  "."id" AS t1_r1, "libraries_version
  "."name" AS t1_r2, "libraries_version
  "."validity" AS t1_r3
FROM "authors_versions"
LEFT OUTER JOIN "books_versions"
  ON "books_versions"."author_id" = "authors_versions"."id"
    AND "books_versions"."validity" @> CAST('2025-10-09 23:57:58.215137' AS timestamptz)
LEFT OUTER JOIN "libraries_versions"
  ON "libraries_versions"."id" = "books_versions"."library_id"
    AND "libraries_versions"."validity" @> CAST('2025-10-09 23:57:58.215137' AS timestamptz)
WHERE (authors_versions.validity @> '2025-10-09 23:57:58.215137'::timestamptz)


SELECT "employees_versions".*
FROM "employees_versions"
INNER JOIN "libraries_versions"
  ON "employees_versions"."library_id" = "libraries_versions"."id"
INNER JOIN "books"
  ON "libraries_versions"."id" = "books"."library_id"
WHERE "books"."author_id" = 1
  AND (upper_inf(libraries_versions.validity))
  AND (employees_versions.validity @> '2025-10-10 14:13:03.021904'::timestamptz)


  