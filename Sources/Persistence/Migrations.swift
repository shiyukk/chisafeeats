import GRDB

/// Schema definition. Versioned via GRDB's `DatabaseMigrator` so future releases
/// can evolve the schema without wiping the user's cached data.
enum Migrations {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "establishment") { t in
                t.column("id", .text).primaryKey()
                t.column("license", .text)
                t.column("dba_name", .text).notNull()
                t.column("aka_name", .text)
                t.column("facility_type", .text)
                t.column("risk", .integer)
                t.column("address", .text)
                t.column("city", .text)
                t.column("state", .text)
                t.column("zip", .text)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("latest_result", .text)
                t.column("latest_result_code", .integer)
                t.column("latest_inspection_date", .text)
                t.column("is_out_of_business", .integer).notNull().defaults(to: false)
            }
            // Composite index drives the map's viewport (bounding-box) range scan.
            try db.create(index: "idx_estab_bbox", on: "establishment",
                          columns: ["latitude", "longitude"])
            try db.create(index: "idx_estab_result", on: "establishment",
                          columns: ["latest_result_code"])
            try db.create(index: "idx_estab_license", on: "establishment",
                          columns: ["license"])

            try db.create(table: "inspection") { t in
                t.column("inspection_id", .text).primaryKey()
                t.column("establishment_id", .text).notNull()
                    .references("establishment", onDelete: .cascade)
                t.column("inspection_date", .text).notNull()
                t.column("inspection_type", .text)
                t.column("results", .text)
                t.column("results_code", .integer)
                t.column("risk", .integer)
                t.column("violations_raw", .text)
            }
            try db.create(index: "idx_insp_estab_date", on: "inspection",
                          columns: ["establishment_id", "inspection_date"])

            try db.create(table: "sync_meta") { t in
                t.column("id", .integer).primaryKey().check { $0 == 1 }
                t.column("last_sync_date", .text)
                t.column("last_sync_at", .text)
                t.column("seed_version", .integer)
            }
            try db.execute(sql: "INSERT INTO sync_meta (id) VALUES (1)")
        }

        migrator.registerMigration("v3_score") { db in
            try db.alter(table: "establishment") { t in
                t.add(column: "score", .integer)   // 0–100 hygiene score, nullable
            }
        }

        migrator.registerMigration("v4_translations") { db in
            // Cache of EN→中文 violation-comment translations (cloud, on demand).
            try db.create(table: "comment_translation") { t in
                t.column("source", .text).primaryKey()
                t.column("target", .text).notNull()
            }
        }

        migrator.registerMigration("v5_sample_key") { db in
            // A precomputed, scrambled sampling key (Knuth multiplicative hash of
            // rowid) with its own index. The map's viewport query orders by this
            // to take a *spatially uniform* capped sample — using a stored,
            // indexed value instead of recomputing + sorting on every query.
            try db.alter(table: "establishment") { t in
                t.add(column: "sample_key", .integer)
            }
            try db.execute(sql: """
                UPDATE establishment
                SET sample_key = (rowid * 2654435761) % 2147483647
                """)
            try db.create(index: "idx_estab_sample", on: "establishment",
                          columns: ["sample_key"])
            // Keep it populated for rows added later by incremental sync.
            try db.execute(sql: """
                CREATE TRIGGER estab_sample_key AFTER INSERT ON establishment
                WHEN NEW.sample_key IS NULL
                BEGIN
                    UPDATE establishment SET sample_key = (NEW.rowid * 2654435761) % 2147483647
                    WHERE rowid = NEW.rowid;
                END
                """)
        }

        migrator.registerMigration("v6_translation_lang") { db in
            // Re-key the translation cache by (source, lang) so a comment can be
            // cached per target language. Existing rows were Chinese.
            try db.execute(sql: "ALTER TABLE comment_translation RENAME TO comment_translation_old")
            try db.create(table: "comment_translation") { t in
                t.column("source", .text).notNull()
                t.column("lang", .text).notNull()
                t.column("target", .text).notNull()
                t.primaryKey(["source", "lang"])
            }
            try db.execute(sql: """
                INSERT INTO comment_translation (source, lang, target)
                SELECT source, 'zh-Hans', target FROM comment_translation_old
                """)
            try db.execute(sql: "DROP TABLE comment_translation_old")
        }

        migrator.registerMigration("v7_latest_inspection_id") { db in
            // Tie-breaks same-day inspections so the snapshot reflects the truly
            // latest event (the bundled seed ships this column already populated).
            try db.alter(table: "establishment") { t in
                t.add(column: "latest_inspection_id", .text)
            }
        }

        return migrator
    }
}
