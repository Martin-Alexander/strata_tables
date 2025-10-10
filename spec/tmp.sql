SELECT
  "authors_versions"."version_id" AS t0_r0, "authors_versions"
  "id" AS t0_r1, "authors_versions"
  "name" AS t0_r2, "authors_versions"
  "country_id" AS t0_r3, "authors_versions"
  "validity" AS t0_r4, "pictures_versions"
  "version_id" AS t1_r0, "pictures_versions"
  "id" AS t1_r1, "pictures_versions"
  "name" AS t1_r2, "pictures_versions"
  "imageable_id" AS t1_r3, "pictures_versions"
  "imageable_type" AS t1_r4, "pictures_versions"
  "validity" AS t1_r5
FROM "authors_versions"
LEFT OUTER JOIN "pictures_versions"
  ON "pictures_versions"."imageable_type" = 'Author'
    AND "pictures_versions"."imageable_id" = "authors_versions"."id"
      AND "pictures_versions"."validity" @> CAST('2025-10-10 16:40:33.741631' AS timestamptz)
WHERE (authors_versions.validity @> '2025-10-10 16:40:33.741631'::timestamptz)
