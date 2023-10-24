# MSM PackingSlip Generator

This tool takes as input a YAML document ("manifest") which shows what a
customer ordered, and generates a PDF of the packing slip. The packing slip
is intended to be printed and shipped to the customer along with the
merchandise.

The YAML manifest refers only to "catalog numbers," so you must also provide
a catalog file which maps catalog numbers to all the other metadata about
the goods you're selling (human-readable description, unit price, etc.)


## Example YAML manifest


```yaml
---
order_no: 1
order_date: "2023-09-29"

manifest:
  -
    catalog_no: 3
    qty: 2
  -
    catalog_no: 5
    qty: 1

bill_to: |
  Perseus Floof
  57345 Calamity Court
  Goalla Gumpy, RI 19535
  United States

ship_to: |
  Boris M. Q. Felicity III
  10 Decimal Way
  Charming, WY 79345
  United States
```


## License

This software is released by Magenta Stripe Media under the terms of a
2-clause BSD-style license. Refer to the LICENSE document.
