#!/usr/bin/env python3
"""fissible/seed MCP server — one tool per generator, bash subprocess transport."""
import subprocess
import os

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    from mcp import FastMCP

mcp = FastMCP("seed")

SEED_SH = os.path.join(os.path.dirname(__file__), "..", "seed.sh")


def _run(generator: str, **kwargs) -> str:
    """Call bash seed.sh <generator> [--key value ...] and return stdout."""
    args = ["bash", SEED_SH, generator]
    for k, v in kwargs.items():
        if v is not None:
            args += [f"--{k}", str(v)]
    try:
        result = subprocess.run(args, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"ERROR: {e.stderr.strip()}"


# --- Scalar tools ---

@mcp.tool()
def seed_name(count: int = 1) -> str:
    """Generate full names (first + last)."""
    return _run("name", count=count)

@mcp.tool()
def seed_first_name(count: int = 1) -> str:
    """Generate first names."""
    return _run("first_name", count=count)

@mcp.tool()
def seed_last_name(count: int = 1) -> str:
    """Generate last names."""
    return _run("last_name", count=count)

@mcp.tool()
def seed_email(count: int = 1) -> str:
    """Generate email addresses (firstname.lastname@domain)."""
    return _run("email", count=count)

@mcp.tool()
def seed_phone(count: int = 1) -> str:
    """Generate US phone numbers in NNN-NNN-NNNN format."""
    return _run("phone", count=count)

@mcp.tool()
def seed_uuid(count: int = 1) -> str:
    """Generate UUID v4 strings."""
    return _run("uuid", count=count)

@mcp.tool()
def seed_date(count: int = 1, from_date: str = None, to_date: str = None) -> str:
    """Generate ISO 8601 dates. from_date/to_date constrain range (YYYY-MM-DD). Default: 2000-01-01 to today."""
    return _run("date", count=count, **{"from": from_date, "to": to_date})

@mcp.tool()
def seed_number(count: int = 1, min: int = None, max: int = None) -> str:
    """Generate random integers. Default range: 1–100 inclusive."""
    return _run("number", count=count, min=min, max=max)

@mcp.tool()
def seed_lorem(count: int = 1, words: int = None, sentences: int = None) -> str:
    """Generate lorem ipsum text. words and sentences are mutually exclusive. Default: 1 sentence."""
    return _run("lorem", count=count, words=words, sentences=sentences)

@mcp.tool()
def seed_ip(count: int = 1) -> str:
    """Generate IPv4 addresses."""
    return _run("ip", count=count)

@mcp.tool()
def seed_url(count: int = 1) -> str:
    """Generate HTTPS URLs with a domain and single path segment."""
    return _run("url", count=count)

@mcp.tool()
def seed_bool(count: int = 1) -> str:
    """Generate true/false values."""
    return _run("bool", count=count)

# --- Core record tools ---

@mcp.tool()
def seed_user(count: int = 1, format: str = "json") -> str:
    """Generate user profiles: name, email, phone, dob, username. Formats: json, kv, csv, sql."""
    return _run("user", count=count, format=format)

@mcp.tool()
def seed_address(count: int = 1, format: str = "json") -> str:
    """Generate US addresses: street, city, state, zip, country."""
    return _run("address", count=count, format=format)

@mcp.tool()
def seed_company(count: int = 1, format: str = "json") -> str:
    """Generate company records with flat address fields."""
    return _run("company", count=count, format=format)

# --- Ecommerce tools ---

@mcp.tool()
def seed_product(count: int = 1, format: str = "json") -> str:
    """Generate products: name, sku, price, category, description, stock_qty."""
    return _run("product", count=count, format=format)

@mcp.tool()
def seed_category(count: int = 1, format: str = "json") -> str:
    """Generate product categories: name, slug, parent_category."""
    return _run("category", count=count, format=format)

@mcp.tool()
def seed_order(count: int = 1, format: str = "json") -> str:
    """Generate orders: order_id, customer_email, status, total, created_at."""
    return _run("order", count=count, format=format)

@mcp.tool()
def seed_order_item(count: int = 1, format: str = "json") -> str:
    """Generate order items: order_id, product_sku, name, qty, unit_price, line_total (derived)."""
    return _run("order_item", count=count, format=format)

@mcp.tool()
def seed_coupon(count: int = 1, format: str = "json") -> str:
    """Generate coupons: code, discount_type (pct/fixed), value, expires_at."""
    return _run("coupon", count=count, format=format)

@mcp.tool()
def seed_cart(count: int = 1, format: str = "json", items: int = None) -> str:
    """Generate shopping carts with embedded items. items = items per cart (default 3, max 10). sql format not supported."""
    return _run("cart", count=count, format=format, items=items)

# --- CRM tools ---

@mcp.tool()
def seed_contact(count: int = 1, format: str = "json") -> str:
    """Generate CRM contacts: name, email, phone, company, title."""
    return _run("contact", count=count, format=format)

@mcp.tool()
def seed_lead(count: int = 1, format: str = "json") -> str:
    """Generate leads: contact fields + source, status, score."""
    return _run("lead", count=count, format=format)

@mcp.tool()
def seed_deal(count: int = 1, format: str = "json") -> str:
    """Generate deals: title, value, stage, close_date, owner."""
    return _run("deal", count=count, format=format)

@mcp.tool()
def seed_activity(count: int = 1, format: str = "json") -> str:
    """Generate CRM activities: type (call/email/meeting), contact_email, activity_date, notes."""
    return _run("activity", count=count, format=format)

@mcp.tool()
def seed_note(count: int = 1, format: str = "json") -> str:
    """Generate notes linked to a contact or deal: body, author, created_at, linked_type, linked_id."""
    return _run("note", count=count, format=format)

@mcp.tool()
def seed_tag(count: int = 1, format: str = "json") -> str:
    """Generate tags: name, color (hex)."""
    return _run("tag", count=count, format=format)

# --- TUI helpers ---

@mcp.tool()
def seed_filenames(count: int = 10) -> str:
    """Generate realistic filenames (newline-delimited). Default: 10."""
    return _run("filenames", count=count)

@mcp.tool()
def seed_dirtree(count: int = 10) -> str:
    """Generate directory path strings (newline-delimited). Default: 10."""
    return _run("dirtree", count=count)

@mcp.tool()
def seed_menu_items(count: int = 10) -> str:
    """Generate title-cased two-word menu labels (newline-delimited). Default: 10."""
    return _run("menu_items", count=count)


if __name__ == "__main__":
    mcp.run()
