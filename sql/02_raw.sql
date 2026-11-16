CREATE TABLE IF NOT EXISTS raw.orders (
  order_id     text,
  customer_id  text,
  order_ts     text,
  status       text,
  channel      text,
  promo_code   text,
  _batch_id    text,
  _loaded_at   timestamptz NOT NULL DEFAULT now(),
  _source_file text
);

CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id          TEXT,
    first_name           TEXT,
    last_name            TEXT,
    email                TEXT,
    phone                TEXT,
    city                 TEXT,
    state                TEXT,
    country              TEXT,
    signup_date          TEXT,
    acquisition_channel  TEXT,

    _batch_id            TEXT,
    _loaded_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    _source_file         TEXT
);

CREATE TABLE IF NOT EXISTS raw.products (
    product_id     TEXT,
    product_name   TEXT,
    category       TEXT,
    subcategory    TEXT,
    brand          TEXT,
    unit_cost      TEXT,
    list_price     TEXT,

    _batch_id      TEXT,
    _loaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    _source_file   TEXT
);

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id      TEXT,
    customer_id   TEXT,
    order_ts      TEXT,
    status        TEXT,
    channel       TEXT,
    promo_code    TEXT,

    _batch_id     TEXT,
    _loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    _source_file  TEXT
);

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_item_id  TEXT,
    order_id       TEXT,
    product_id     TEXT,
    quantity       TEXT,
    unit_price     TEXT,
    discount_pct   TEXT,

    _batch_id      TEXT,
    _loaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    _source_file   TEXT
);

CREATE TABLE IF NOT EXISTS raw.payments (
    payment_id    TEXT,
    order_id      TEXT,
    method        TEXT,
    amount        TEXT,
    paid_ts       TEXT,
    status        TEXT,

    _batch_id     TEXT,
    _loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    _source_file  TEXT
);


CREATE TABLE IF NOT EXISTS raw.shipments (
    shipment_id    TEXT,
    order_id       TEXT,
    carrier        TEXT,
    shipped_ts     TEXT,
    delivered_ts   TEXT,
    promised_date  TEXT,

    _batch_id      TEXT,
    _loaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    _source_file   TEXT
);
