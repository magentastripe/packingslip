# Magenta Stripe Media `packingslip` Documentation

## Manifest file format

Among the data which the `packingslip` tool takes as input is YAML file
called the **manifest**. The manifest contains all of the data that is
unique to a specific purchase: the exact items ordered, the address to which
they will be shipped, etc.

### Keys

At the top level, the manifest is a single [mapping][1] which describes the
particulars of the shipment.

[1]: https://yaml.org/spec/1.2.2/#mapping

The manifest MUST have the following keys:

- `order_no` -- a unique number for your company's bookkeeping.
- `order_date` -- the date on which the customer placed the order.
- `items` -- a sequence of mappings which described the individual
  line-items and the quantity ordered of each (described below)
- `bill_to` -- the billing address for the order
- `ship_to` -- the shipping address for the order

Each individual item in the sequence of `items` is mapping with the
following keys:

- `catalog_no` -- the ID for the particular item
- `qty` -- the quantity ordered for this particular item


### Example manifest

```yaml
---
order_no: 1
order_date: "2023-09-29"

items:
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
2-clause BSD-style license. Please refer to the LICENSE document.
