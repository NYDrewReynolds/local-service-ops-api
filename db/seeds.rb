admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "password123")

AdminUser.find_or_create_by!(email: admin_email) do |admin|
  admin.password = admin_password
end

services = [
  { name: "Removal", code: "tree_removal" },
  { name: "Trimming", code: "trimming" },
  { name: "Stump Grinding", code: "stump_grinding" }
]

services.each do |service|
  Service.find_or_create_by!(code: service[:code]) { |record| record.name = service[:name] }
end

subcontractors = [
  {
    name: "Pine Ridge Tree Co",
    phone: "555-0101",
    email: "dispatch@pineridge.example",
    service_codes: %w[tree_removal trimming],
    base_location: { city: "Austin", state: "TX" }
  },
  {
    name: "Canopy Care Partners",
    phone: "555-0102",
    email: "ops@canopycare.example",
    service_codes: %w[trimming stump_grinding],
    base_location: { city: "Round Rock", state: "TX" }
  },
  {
    name: "Root & Branch Services",
    phone: "555-0103",
    email: "hello@rootbranch.example",
    service_codes: %w[tree_removal stump_grinding],
    base_location: { city: "Georgetown", state: "TX" }
  }
]

subcontractors.each do |attrs|
  Subcontractor.find_or_create_by!(name: attrs[:name]) do |record|
    record.phone = attrs[:phone]
    record.email = attrs[:email]
    record.service_codes = attrs[:service_codes]
    record.base_location = attrs[:base_location]
  end
end

default_availability = (1..5).flat_map do |day|
  [
    { day_of_week: day, window_start: "09:00", window_end: "12:00" },
    { day_of_week: day, window_start: "13:00", window_end: "16:00" }
  ]
end

availability_by_name = {
  "Pine Ridge Tree Co" => [
    { day_of_week: 1, window_start: "08:00", window_end: "11:30" },
    { day_of_week: 3, window_start: "12:30", window_end: "16:30" },
    { day_of_week: 5, window_start: "09:00", window_end: "14:00" }
  ],
  "Canopy Care Partners" => [
    { day_of_week: 2, window_start: "10:00", window_end: "15:00" },
    { day_of_week: 4, window_start: "08:30", window_end: "12:30" },
    { day_of_week: 4, window_start: "13:30", window_end: "17:00" }
  ],
  "Root & Branch Services" => [
    { day_of_week: 1, window_start: "07:30", window_end: "10:30" },
    { day_of_week: 2, window_start: "12:00", window_end: "16:30" },
    { day_of_week: 5, window_start: "09:30", window_end: "12:30" }
  ]
}

Subcontractor.find_each do |subcontractor|
  slots = availability_by_name.fetch(subcontractor.name, default_availability)
  slots.each do |slot|
    SubcontractorAvailability.find_or_create_by!(
      subcontractor: subcontractor,
      day_of_week: slot[:day_of_week],
      window_start: slot[:window_start],
      window_end: slot[:window_end]
    )
  end
end

pricing_rules = [
  { service_code: "tree_removal", min_price_cents: 50000, max_price_cents: 250000, base_price_cents: 120000 },
  { service_code: "trimming", min_price_cents: 20000, max_price_cents: 90000, base_price_cents: 45000 },
  { service_code: "stump_grinding", min_price_cents: 30000, max_price_cents: 120000, base_price_cents: 65000 }
]

pricing_rules.each do |rule|
  PricingRule.find_or_create_by!(service_code: rule[:service_code]) do |record|
    record.min_price_cents = rule[:min_price_cents]
    record.max_price_cents = rule[:max_price_cents]
    record.base_price_cents = rule[:base_price_cents]
  end
end

leads = [
  {
    full_name: "Jordan Blake",
    email: "jordan.blake@example.com",
    phone: "555-0201",
    address_line1: "123 Maple St",
    city: "Austin",
    state: "TX",
    postal_code: "78701",
    service_requested: "Large tree removal",
    notes: "Oak tree leaning over garage.",
    urgency_hint: "ASAP"
  },
  {
    full_name: "Riley Chen",
    email: "riley.chen@example.com",
    phone: "555-0202",
    address_line1: "456 Cedar Ave",
    city: "Pflugerville",
    state: "TX",
    postal_code: "78660",
    service_requested: "Seasonal trimming",
    notes: "Front yard hedges and tree limbs.",
    urgency_hint: "this week"
  },
  {
    full_name: "Morgan Patel",
    email: "morgan.patel@example.com",
    phone: "555-0203",
    address_line1: "789 Pine Dr",
    city: "Round Rock",
    state: "TX",
    postal_code: "78664",
    service_requested: "Stump grinding",
    notes: "Two old stumps near driveway.",
    urgency_hint: "next week"
  },
  {
    full_name: "Casey Nguyen",
    email: "casey.nguyen@example.com",
    phone: "555-0204",
    address_line1: "321 Birch Rd",
    city: "Georgetown",
    state: "TX",
    postal_code: "78626",
    service_requested: "Tree removal and cleanup",
    notes: "Pine tree is dead; wants haul away.",
    urgency_hint: "this month"
  },
  {
    full_name: "Avery Singh",
    email: "avery.singh@example.com",
    phone: "555-0205",
    address_line1: "654 Walnut Ln",
    city: "Austin",
    state: "TX",
    postal_code: "78745",
    service_requested: "Trimming over roof",
    notes: "Branches scraping roof during wind.",
    urgency_hint: "soon"
  }
]

leads.each do |lead_attrs|
  Lead.find_or_create_by!(full_name: lead_attrs[:full_name], address_line1: lead_attrs[:address_line1]) do |record|
    record.email = lead_attrs[:email]
    record.phone = lead_attrs[:phone]
    record.city = lead_attrs[:city]
    record.state = lead_attrs[:state]
    record.postal_code = lead_attrs[:postal_code]
    record.service_requested = lead_attrs[:service_requested]
    record.notes = lead_attrs[:notes]
    record.urgency_hint = lead_attrs[:urgency_hint]
  end
end
