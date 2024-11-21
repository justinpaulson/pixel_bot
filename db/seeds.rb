puts "Starting Seeds..."


users = [
  {
    email: "test@example.com",
    password: "1234"
  }
]

puts "Seeding users..."
users.each do |user|
  User.find_or_create_by!(email_address: user[:email]) do |u|
    u.password = user[:password]
  end
end
puts "Seeded #{User.count} users!"

puts "Seeding complete!"
