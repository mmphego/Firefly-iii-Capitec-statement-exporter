#!/usr/bin/env python3

import argparse
import os
import pathlib
import re
import time
import typing
from datetime import datetime
from enum import Enum

import requests
from dotenv import load_dotenv

import pandas as pd
import pdftotext
from utils import (categorise_statement, convert_str_float, format_df_date,
                   print_all, rename_df_cols, search_budget_id, update_if_nan)


class ColNames(Enum):
    Posting_Date = 1
    Transaction_Date = 2
    Description = 3
    Money_In_Out = 4
    Balance = 5


class ExtractStatement:
    def __init__(self, pdf_statement):
        self.pdf_statement = pdf_statement
        self.column_labels = ColNames

    def pdf_to_text(self):
        with open(self.pdf_statement, "rb") as f:
            pdf = pdftotext.PDF(f)
        return {f"Page{count}": content for count, content in enumerate(pdf, 1)}

    def get_statement(self):
        pdf_text = self.pdf_to_text()
        statement = []
        for page, content in pdf_text.items():
            page_content = content.rsplit("\n")
            page_content = [content for content in page_content if content]
            statement_lines = [
                line
                for line in page_content
                if (line[-2:].isnumeric() and line[-3:-2] == ".")
            ]
            statement.extend(statement_lines)
        return statement

    def split_statement_lines(self):
        statement = self.get_statement()
        pattern = re.compile(r"\s+\s+")
        statement_lines_strip = [
            re.sub(pattern, ":", statement_line).split(":")
            for statement_line in statement
        ]
        statement_lines_clean = [line for line in statement_lines_strip if len(line) > 3]
        return statement_lines_clean

    def format_statement(self):
        statement = self.split_statement_lines()
        _ = [i.insert(0, "") for i in statement if (len(i) < 5) and i[0] == ""]

        for idx, i in enumerate(statement):
            if len(i) > 5 and i[0][:2].isdigit() and i[1][:2].isdigit():
                statement[idx] = [i[0], i[1], "".join(i[2:-2]), i[4], i[5]]
        return statement

    def get_statement_df(self):
        formatted_statement = self.format_statement()
        df = pd.DataFrame(formatted_statement)
        statement_df = rename_df_cols(df, new_names=[i.name for i in self.column_labels])
        for i in self.column_labels:
            if "posting" in i.name.lower():
                format_statement_df = format_df_date(statement_df, i.name)
            if "transaction" in i.name.lower():
                format_statement_df = format_df_date(statement_df, i.name)
            if "balance" in i.name.lower() or "money" in i.name.lower():
                format_statement_df = convert_str_float(statement_df, i.name)

        for i in self.column_labels:
            if "posting" in i.name.lower() or "transaction" in i.name.lower():
                format_statement_df = update_if_nan(format_statement_df, i.name)

        return format_statement_df


class Firefly:
    def __init__(self, hostname, auth_token):
        self.headers = {"Authorization": f"Bearer {auth_token}"}
        self.hostname = f"{hostname}/api/v1/"
        self.get_about_user()

    def _post(self, endpoint, payload):
        return requests.post(
            f"{self.hostname}{endpoint}", json=payload, headers=self.headers
        )

    def _get(self, endpoint, params=None):
        response = requests.get(
            f"{self.hostname}{endpoint}", params=params, headers=self.headers
        )

        return response.json()

    def get_budgets(self):
        return self._get("budgets")

    def get_req_by_name(self, req_name):
        return self._get(req_name)

    def get_accounts(self, account_type="asset"):
        return self._get("accounts", params={"type": account_type})

    def get_about_user(self):
        return self._get("about/user")

    def simplified_budget(self):
        return {
            budget["attributes"]["name"]: budget["id"]
            for budget in self.get_budgets()["data"]
        }

    def create_transaction(
        self,
        description: str,
        amount: str,
        date_created: str,
        destination_name: str = "Cash account",
        source_account_id: int = 1,
        category_name: str = "Unexpected Expenses",
        budget_id: int = None,
    ):
        if not date_created:
            date_created = datetime.now().strftime("%Y-%m-%d")

        payload = {
            "transactions": [
                {
                    "type": "withdrawal",
                    "date": date_created,
                    "amount": amount,
                    "description": description,
                    "source_id": source_account_id,
                    "destination_name": destination_name,
                    "budget_id": budget_id,
                    "category_name": category_name,
                }
            ]
        }

        return self._post(endpoint="transactions", payload=payload)


def parse_args():
    parser = argparse.ArgumentParser(description="")
    parser.add_argument("--pdf", required=True, help="Capitec Bank Statement (pdf)")
    parser.add_argument(
        "--firefly-host", default="http://localhost:8000", help="Firefly Host"
    )
    parser.add_argument(
        "--firefly-api",
        help=(
            "Firefly API token, Alternatively: Add it in your .env Or environment "
            "export, save as `FIREFLY_TOKEN=xxx`"
        ),
    )

    return vars(parser.parse_args())


def main():
    env_path = pathlib.Path(".") / ".env"
    load_dotenv(dotenv_path=env_path)

    args = parse_args()

    api_token = os.getenv("FIREFLY_TOKEN", args.get("firefly_api"))
    firefly = Firefly(args.get("firefly_host"), api_token)
    f_budget = firefly.simplified_budget()

    pdf_filename = pathlib.Path(args.get("pdf")).absolute()
    statement_obj = ExtractStatement(pdf_filename)
    statement_df = statement_obj.get_statement_df()
    categorised_df = categorise_statement(statement_df)

    for idx, row in categorised_df.iterrows():
        _, date_created, description, category, budget, amount, _ = row.to_list()
        category = "Unexpected Expenses" if category is None else category
        budget = "Unexpected Expenses" if budget is None else budget
        date_created = str(date_created.strftime("%Y-%m-%d"))
        budget_id = search_budget_id(category, f_budget)
        resp = firefly.create_transaction(
            description=description,
            amount=str(amount),
            date_created=date_created,
            category_name=category,
            budget_id=int(budget_id),
        )
        assert resp.status_code == 200
        time.sleep(0.1)
    print(f"Updated {len(categorised_df)} items Successfully!")


if __name__ == "__main__":
    main()
