import pandas as pd

import categories


def update_df_cols(
    df, description_column, description_query, update_column, update_value
):
    df.loc[
        df_find_by(df, description_column, description_query).index, update_column
    ] = update_value.title()

    return df


def categoriser(
    df,
    avail_categories,
    desc_column="Description",
    cat_column="Category",
    bud_column="Budget",
):
    # FIXME: There must be a better way.
    for budget, cats in avail_categories.items():
        for cat, desc in cats.items():
            if isinstance(desc, list):
                for d in desc:
                    df = update_df_cols(df, desc_column, d, cat_column, cat)
                    df = update_df_cols(df, desc_column, d, bud_column, budget)
            elif isinstance(desc, dict):
                for c, d in desc.items():
                    for _d in d:
                        df = update_df_cols(df, desc_column, _d, cat_column, f"{cat}-{c}")
                        df = update_df_cols(df, desc_column, _d, bud_column, budget)
    return df


def categorise_statement(df, cat_column="Category", bud_column="Budget"):
    df.insert(3, cat_column, "")
    df.insert(4, bud_column, "")
    df = categoriser(df, categories.CATEGORIES)
    return df


def convert_str_float(df, column_name):
    df[column_name] = df[column_name].str.replace(" ", "")
    df[column_name] = df[column_name].astype(float)
    return df


def df_find_by(df, column_name, query):
    return df[df[column_name].str.contains(query, case=False)]


def format_df_date(df, column_name, date_format="%d/%m/%Y"):
    df[column_name] = pd.to_datetime(df[column_name], format=date_format, errors="coerce")
    return df


def print_all(df):
    pd.set_option("display.max_rows", df.shape[0] + 1)
    return df


def rename_df_cols(df, new_names=[], prefix=None, suffix=None):
    if new_names and (len(df.columns) == len(new_names)):
        df.columns = new_names
        df.columns = df.columns.str.replace(" ", "_")
    if prefix:
        df = df.add_prefix(prefix)
    if suffix:
        df = df.add_suffix(suffix)
    return df


def update_if_nan(df, column_name):
    nat_rows = df[df[column_name].isnull()]
    for idx in nat_rows.index:
        df.loc[idx - 1][column_name]
        df = df.fillna(df.loc[idx - 1][column_name])
    return df
