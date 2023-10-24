#
# MAGENTA STRIPE MEDIA
# Packing Slip Generator Tool
#

require 'optparse'
require 'prawn'
require 'prawn/table'
require 'yaml'

########## ########## ##########

# Just a namespace.
module MagentaStripeMedia
end

########## ########## ##########

# Custom TSV reader.
class MagentaStripeMedia::TSVReader
  include Enumerable

  ONE_OR_MORE_TABS = /\t+/.freeze

  attr_reader :data

  def initialize(filename)
    @data = []

    fp = File.open(filename, "r")
    columns = fp.gets.chomp.split(ONE_OR_MORE_TABS)

    until fp.eof?
      line = fp.gets
      next if not line
      record = line.chomp.split(ONE_OR_MORE_TABS)
      datum = {}

      columns.each_with_index do |column_name, index|
        datum[column_name] = record[index]
      end

      @data << datum
    end

    fp.close
  end

  def each
    @data.each { |datum| yield datum }
  end
end

########## ########## ##########

# A single line item in the invoice.
class MagentaStripeMedia::Item
  attr_accessor :name
  attr_accessor :catalog_no
  attr_accessor :qty
  attr_accessor :unit_price

  def initialize
    @name = "(untitled)"
    @catalog_no = "MSM-00000"
    @qty = 0
    @unit_price = 0.00
  end

  def to_prawn_data
    return [
      @catalog_no.to_s,
      @name.to_s,
      self.unit_price_to_s,
      @qty.to_s,
      self.total_price_to_s,
    ]
  end

  def unit_price_to_s
    return sprintf("$%0.2f", @unit_price)
  end

  def total_price_to_s
    return sprintf("$%0.2f", @unit_price * @qty)
  end
end

########## ########## ##########

# A complete order from a customer.
class MagentaStripeMedia::Manifest
  attr_reader :catalog
  attr_reader :business_info
  attr_reader :items
  attr_reader :bill_to
  attr_reader :ship_to
  attr_reader :order_no
  attr_reader :order_date

  # - :catalog_data => String
  # - :business_info => String
  # - :manifest_file => String
  def initialize(**kwargs)
    @catalog = MagentaStripeMedia::TSVReader.new(kwargs[:catalog_data]).data
    @business_info = YAML.load(File.read(kwargs[:business_info]))
    details = YAML.load(File.read(kwargs[:manifest_file]))

    @items = details["manifest"].map do |data|
      catalog_no = sprintf("MSM-%05d", data["catalog_no"])
      the_product = @catalog.detect { |product| product["CATALOG-NO"] == catalog_no }

      item = MagentaStripeMedia::Item.new
      item.catalog_no = the_product["CATALOG-NO"] = catalog_no
      item.name = the_product["TITLE"]
      item.qty = data["qty"].to_i
      item.unit_price = the_product["UNIT-PRICE"].to_f
      item
    end

    @bill_to = details["bill_to"]
    @ship_to = details["ship_to"]
    @order_no = sprintf("%08d", details["order_no"])
    @order_date = details["order_date"]
  end
end

########## ########## ##########

# The invoice itself.
class MagentaStripeMedia::InvoiceGenerator
  include Enumerable

  DPI = 72
  HELVETICA = "Helvetica".freeze

  attr_accessor :manifest
  attr_accessor :s_and_h

  # - :manifest => MagentaStripeMedia::Manifest
  # - :s_and_h => Float
  def initialize(**kwargs)
    @manifest = kwargs[:manifest] || raise(ArgumentError, "expected a manifest")
    @s_and_h = kwargs[:s_and_h] || 0.00
  end

  def main(outfile)
    pdf = Prawn::Document.new({
      :page_size => [inches(8.5), inches(11)],
      :margin => [inches(0.5), inches(0.5), inches(0.5), inches(0.5)],
      :page_layout => :portrait,
    })
    pdf.font(HELVETICA, :size => 10, :style => :normal)

    pdf.image("./data/logo-head-transparent.png", **{
      :position => :center,
      :height => inches(1.25),
    })

    pdf.font(HELVETICA, :size => 12, :style => :bold) do
      pdf.text("\n#{@manifest.business_info['name']}\n", :align => :center)
    end

    pdf.font(HELVETICA, :size => 10, :style => :normal) do
      @manifest.business_info["address"].split("\n").each do |line|
        pdf.text(line + "\n", :align => :center)
      end
      pdf.text("\n")
    end

    pdf.font(HELVETICA, :size => 12, :style => :bold) do
      pdf.text("PACKING SLIP - ORDER # #{@manifest.order_no} - #{@manifest.order_date}\n\n")
    end

    ##########

    shipping_data = [
      ["BILL TO:", "SHIP TO:"],
      [@manifest.bill_to, @manifest.ship_to],
    ]

    pdf.table(shipping_data) do |table|
      table.style(table.row(0), :font_style => :bold)
    end

    ##########

    pdf.text("\n\n")

    data = [
      ["Catalog no.", "Name", "Unit price", "Qty.", "Amount"]
    ]

    @manifest.items.each { |item| data << item.to_prawn_data }

    pdf.table(data, :cell_style => {:padding => inches(0.15)}) do |table|
      table.style(table.row(0), :font_style => :bold)
    end

    pdf.font(HELVETICA, :size => 12) do
      pdf.text(sprintf("\n<b>SUBTOTAL:</b> $%0.2f\n", self.subtotal), :inline_format => true)
      pdf.text(sprintf("<b>SHIPPING & HANDLING:</b> $%0.2f\n", @s_and_h), :inline_format => true)
      pdf.text(sprintf("<b>TOTAL:</b> $%0.2f\n\n", self.grand_total), :inline_format => true)
    end

    ##########

    pdf.text(@manifest.business_info["signoff"])

    ##########

    pdf.render_file(outfile)
    return 0
  end

  def each
    @items.each { |item| yield item }
  end

  def inches(n)
    return n * DPI
  end

  def subtotal
    return @manifest.items.reduce(0.00) { |total, item|
      total + (item.unit_price * item.qty)
    }
  end

  def grand_total
    return self.subtotal + @s_and_h
  end
end

########## ########## ##########

if $0 == __FILE__
  def die(message)
    $stderr.puts("FATAL: #{message}")
    exit 1
  end

  catalog_data_file = "./data/MSM_CATALOG.tsv"
  business_info_file = "./data/BUSINESS_INFO.yaml"
  manifest_file = nil
  outfile = nil

  parser = OptionParser.new do |opts|
    opts.on("-m", "--manifest FILE") { |path|
      manifest_file = File.expand_path(path)
    }
    opts.on("-o", "--output FILE") { |path|
      outfile = File.expand_path(path)
    }
    opts.on("-c", "--catalog FILE", "default: #{catalog_data_file}") { |path|
      catalog_data_file = File.expand_path(path)
    }
    opts.on("-b", "--business-info FILE", "default: #{business_info_file}") { |path|
      business_info_file = File.expand_path(path)
    }
  end
  parser.parse!(ARGV)

  die("expected a manifest file") if not manifest_file
  die("expected an outfile") if not outfile
  die("no such file: #{catalog_data_file}") if not File.file?(catalog_data_file)
  die("no such file: #{business_info_file}") if not File.file?(business_info_file)

  invoicer = MagentaStripeMedia::InvoiceGenerator.new(**{
    :manifest => MagentaStripeMedia::Manifest.new(**{
      :catalog_data => catalog_data_file,
      :business_info => business_info_file,
      :manifest_file => manifest_file,
    }),
    :s_and_h => 1.23,
  })

  begin
    rv = invoicer.main(outfile)
  rescue
    rv = 1
  ensure
    exit rv
  end
end
