-- =============================================================================
-- 09_reviews.sql
-- Отзывы о усопшем. Модерация админом. Защита от спама — уникальность автор+текст.
-- =============================================================================

CREATE TABLE memorial_reviews (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    memorial_id             UUID         NOT NULL REFERENCES memorials (id) ON DELETE CASCADE,
    author_user_id          UUID         REFERENCES users (id) ON DELETE SET NULL,
    author_name             VARCHAR(128) NOT NULL,
    author_email            CITEXT,
    body                    TEXT         NOT NULL,
    moderation_status_id    SMALLINT     NOT NULL REFERENCES review_moderation_statuses (id),
    moderated_by_user_id    UUID         REFERENCES users (id) ON DELETE SET NULL,
    moderated_at            TIMESTAMPTZ,
    moderation_note         VARCHAR(256),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT chk_memorial_reviews_body_len CHECK (char_length(body) BETWEEN 3 AND 5000)
);

CREATE INDEX idx_memorial_reviews_memorial ON memorial_reviews (memorial_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_memorial_reviews_moderation ON memorial_reviews (moderation_status_id)
    WHERE deleted_at IS NULL;

-- Один отзыв от одного авторизованного пользователя на мемориал
CREATE UNIQUE INDEX uq_memorial_reviews_user_per_memorial
    ON memorial_reviews (memorial_id, author_user_id)
    WHERE author_user_id IS NOT NULL AND deleted_at IS NULL;
