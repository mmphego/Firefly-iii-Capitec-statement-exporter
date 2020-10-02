import pandas as pd


def convert_str_float(df, column_name):
    df[column_name] = df[column_name].str.replace(" ", "")
    df[column_name] = df[column_name].astype(float)
    return df


def df_find_by(df, column_name, str_content):
    return df[df[column_name].str.contains(str_content, case=False)]


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
