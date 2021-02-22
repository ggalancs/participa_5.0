class VoteCircle < ActiveRecord::Base
  include TerritoryDetails

  attr_accessor :circle_type

  ransacker :vote_circle_province_id, formatter: proc { |value|
    VoteCircle.where("code like ?", value).map { |vote_circle| vote_circle.code }.uniq
  } do |parent|
    parent.table[:code]
  end

  ransacker :vote_circle_autonomy_id, formatter: proc { |value|
    VoteCircle.where("code like ?", value).map { |vote_circle| vote_circle.code }.uniq
  } do |parent|
    parent.table[:code]
  end

  def is_active?
    self.code.present?
  end

  def get_code_circle(muni_code,circle_type ="TM")
    result =""
    if (circle_type == "TM" || circle_type == "TB")
      options = {town_code: muni_code, country_code: 'ES',generate_dc: true, result_as: :struct}
      td = territory_details options
      ccaa = td.autonomy_code[2..3]
      prov = td.province_code[2..3]
      mun = td.town_code[5..7]
      code = "#{ccaa}#{prov}#{mun}"
      ind = get_next_circle_id code
      result = "#{circle_type}#{ccaa}#{prov}#{mun}#{ind}"
    elsif circle_type =="TC"
      result = get_next_circle_region_id muni_code
    elsif circle_type =="00"
      # exterior circle creation not contemplated
      result = "00"
    end
    result
  end

  def in_spain?
    circle_type =self.code[0,2]
    circle_type == "TB" || circle_type == "TM" || circle_type == "TC"
  end

  def is_exterior?
    circle_type =self.code[0,2]
    circle_type != "IP" && circle_type != "TB" && circle_type != "TC" && circle_type != "TM"
  end

  def get_type_circle
    self.in_spain? ? self.code[0,2] : "00"
  end

  def get_type_circle_from_original_code
    self.in_spain? ? self.original_code[0,2] : "00"
  end

  def island_name
    return "" unless self.town && Podemos::GeoExtra::ISLANDS[self.town]
    Podemos::GeoExtra::ISLANDS[self.town][1]
  end

  def town_name
    if self.town
      prov = Carmen::Country.coded("ES").subregions[self.town[2,2].to_i-1]
      prov.subregions.coded(self.town).name
    else
      ""
    end
  end

  def province_name
    self.province_code ? Carmen::Country.coded("ES").subregions[self.province_code[2,2].to_i-1].name : ""
  end

  def autonomy_name
    self.province_code ? Podemos::GeoExtra::AUTONOMIES[self.province_code][1] :""
  end

  def country_name
    Carmen::Country.coded(self.country_code).name
  end

  private

  def get_next_circle_id(territory_code,circle_type = "TM")
    num_circles = VoteCircle.where("code like ?","#{circle_type}#{territory_code}%").count
    (num_circles + 1).to_s.rjust(2,"0")
  end

  def get_next_circle_region_id(muni_code,country_code = "ES")
    country = Carmen::Country.coded(country_code)
    town_code = muni_code[5..7].to_i > 0 ? muni_code[5..7] : "000"
    province_code= muni_code[2,2]
    autonomy_code = Podemos::GeoExtra::AUTONOMIES["p_#{province_code}"  ][0]
    region_code="#{autonomy_code[2,2]}#{province_code}#{town_code}"
    last_code = VoteCircle.where("code like ?","TC#{region_code}%").order(:code).pluck(:code).last
    ind = last_code.present? ? (last_code[9..-1].to_i + 1).to_s.rjust(2,"0") : "01"
    "TC#{region_code}#{ind}"
  end
end
