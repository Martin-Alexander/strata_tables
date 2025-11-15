## Combination, Bitemporal Data Model

```ruby
class CreateEmployees < ActiveRecord::Migration[8.1]
  using Temporal::SchemaStatements

  def change
    create_table :employees, primary_key: [:id, :version], system_versioning: true do |t|
      t.bigserial :id, null: false
      t.bigint :version, null: false, default: 1
      t.integer :salary
      t.tstzrange :validity, null: false
    end
  end
end

class Employee < ActiveRecord::Base
  include Temporal::ApplicationVersioned

  self.time_dimension = :validity
end

module History
  include Temporal::SystemVersioningNamespace
end

# System time: 2000-01-07

employee = Employee.create(salary: 100, validity: Time.parse("2000-01-05")...)
# => #<Employee id: 1, version: 1, salary: 100, validity: 2000-01-05...>

# System time: 2000-01-14

employee_v2 = employee.revise_at(Time.parse("2000-01-12")).with(salary: 200)
# => #<Employee id: 1, version: 2, salary: 200, validity: 2000-01-12...>

employee
# => #<Employee id: 1, version: 1, salary: 100, validity: 2000-01-05...2000-01-12>

# System time: 2000-01-28

employee_v2.inactive_at(Time.parse("2000-01-19"))
# => #<Employee id: 1, version: 2, salary: 200, validity: 2000-01-12...2000-01-19>

History::Employee.all
# => [
#   #<History::Employee id: 1, version: 1, salary: 100, validity: 2000-01-05..., system_period: 2000-01-07...2000-01-14>,
#   #<History::Employee id: 1, version: 1, salary: 100, validity: 2000-01-05...2000-01-12, system_period: 2000-01-14...>,
#   #<History::Employee id: 1, version: 2, salary: 200, validity: 2000-01-12..., system_period: 2000-01-14...2000-01-28>,
#   #<History::Employee id: 1, version: 2, salary: 200, validity: 2000-01-12...2000-01-19, system_period: 2000-01-28...>
# ]

Employee.all
# => [
#   #<Employee id 1, version: 1, salary: 100, validity: 2000-01-05...2000-01-12>,
#   #<Employee id 1, version: 2, salary: 200, validity: 2000-01-12...2000-01-19>
# ]

# System time: 2000-02-04

employee_v1 = Employee.at_time(Time.parse("2000-01-07")).find_by(id: 1)
# => #<Employee id: 1, version: 1, salary: 100, validity: 2000-01-05...2000-01-12>

employee_v1.update(salary: 80)
# => #<Employee id: 1, version: 1, salary: 80, validity: 2000-01-05...2000-01-12>

History::Employee.all
# => [
#   #<History::Employee id: 1, version: 1, salary: 100, validity: 2000-01-05..., system_period: 2000-01-07...2000-01-14>,
#   #<History::Employee id: 1, version: 1, salary: 100, validity: 2000-01-05...2000-01-12, system_period: 2000-01-14...2000-02-04>,
#   #<History::Employee id: 1, version: 2, salary: 200, validity: 2000-01-12..., system_period: 2000-01-14...2000-01-28>,
#   #<History::Employee id: 1, version: 2, salary: 200, validity: 2000-01-12...2000-01-19, system_period: 2000-01-28...>,
#   #<History::Employee id: 1, version: 1, salary: 100, validity: 2000-01-05...2000-01-12, system_period: 2000-01-14...>,
#   #<History::Employee id: 1, version: 1, salary: 80, validity: 2000-01-05...2000-01-12, system_period: 2000-02-04...>
# ]

Employee.all
# => [
#   #<Employee id 1, version: 1, salary: 80, validity: 2000-01-05...2000-01-12>,
#   #<Employee id 1, version: 2, salary: 200, validity: 2000-01-12...2000-01-19>
# ]

# On February 1st, what did with the system think the salary of employee #1 was on January 7th?
History::Employee
  .at_time(sys_period: Time.parse("2000-02-01"), validity: Time.parse("2000-01-07"))
  .find_by(id: 1)
  .salary
# => 100

# What does the system currently think the salary of employee #1 was on January 7th?
History::Employee
  .at_time(sys_period: Time.current, validity: Time.parse("2000-01-07"))
  .find_by(id: 1)
  .salary
# => 80

# System time: 2000-02-11

employee_1 = Employee.last_versions.find(id: 1)
# => #<Employee id 1, version: 2, salary: 200, validity: 2000-01-12...2000-01-19>

employee_1.update(validity_end: nil)
# => #<Employee id 1, version: 2, salary: 200, validity: 2000-01-12...>

History::Employee.all
# => [
#   #<History::Employee id: 1, version: 1, salary: 100, validity: 2000-01-05..., system_period: 2000-01-07...2000-01-14>,
#   #<History::Employee id: 1, version: 1, salary: 100, validity: 2000-01-05...2000-01-12, system_period: 2000-01-14...2000-02-04>,
#   #<History::Employee id: 1, version: 2, salary: 200, validity: 2000-01-12..., system_period: 2000-01-14...2000-01-28>,
#   #<History::Employee id: 1, version: 2, salary: 200, validity: 2000-01-12...2000-01-19, system_period: 2000-01-28...2000-02-11>,
#   #<History::Employee id: 1, version: 1, salary: 100, validity: 2000-01-05...2000-01-12, system_period: 2000-01-14...>,
#   #<History::Employee id: 1, version: 1, salary: 80, validity: 2000-01-05...2000-01-12, system_period: 2000-02-04...>,
#   #<History::Employee id: 1, version: 2, salary: 200, validity: 2000-01-12..., system_period: 2000-02-11...>
# ]
```