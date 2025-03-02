defmodule LoremIpsum.HelperTest do
  @moduledoc false

  use LoremIpsumWeb.ConnCase

  import LoremIpsum.Fixtures

  alias Ecto.Changeset
  alias LoremIpsum.Helper

  # Gets a paginated list of resources
  describe "paginate/2" do
    import Ecto.Query, warn: false

    alias LoremIpsum.Accounts.User

    setup [:pagination_records]

    test "return paginated list", %{
      pagination_records: %{
        user_01: user_01,
        user_02: user_02,
        user_03: user_03,
        user_04: user_04,
        user_05: user_05,
        user_06: user_06,
        user_07: user_07,
        user_08: user_08,
        user_09: user_09,
        user_10: user_10
      }
    } do
      query = from(u in User)
      attrs = %{}

      # Check response
      assert %{
        records: [
          record_01,
          record_02,
          record_03,
          record_04,
          record_05,
          record_06,
          record_07,
          record_08,
          record_09,
          record_10
        ],
        count: 10,
        page: 1,
        total_count: 10,
        total_pages: 1,
        query: %{
          offset: 0,
          limit: 15,
          field: :inserted_at,
          order: :asc
        },
      } = Helper.paginate(query, attrs)
      # Check 1st returned record
      assert record_01.id == user_01.id
      assert record_02.id == user_02.id
      assert record_03.id == user_03.id
      assert record_04.id == user_04.id
      assert record_05.id == user_05.id
      assert record_06.id == user_06.id
      assert record_07.id == user_07.id
      assert record_08.id == user_08.id
      assert record_09.id == user_09.id
      assert record_10.id == user_10.id
    end

    test "handle default \'limit\' on query parameters" do
      query = from(u in User)
      attrs = %{}

      # Check response
      assert %{query: %{limit: 15}} = Helper.paginate(query, attrs)
    end

    test "handle valid \'limit\' on query parameters" do
      query = from(u in User)
      attrs = %{"limit" => "5"}

      # Check response
      assert %{query: %{limit: 5}} = Helper.paginate(query, attrs)
    end

    test "handle invalid \'limit\' on query parameters" do
      query = from(u in User)
      attrs = %{"limit" => "invalid-limit"}

      # Check response
      assert %{query: %{limit: 15}} = Helper.paginate(query, attrs)
    end

    test "handle min \'limit\' on query parameters" do
      query = from(u in User)
      attrs = %{"limit" => "-1"}

      # Check response
      assert %{query: %{limit: 1}} = Helper.paginate(query, attrs)
    end

    test "handle max \'limit\' on query parameters" do
      query = from(u in User)
      attrs = %{"limit" => "999999999"}

      # Check response
      assert %{query: %{limit: 250}} = Helper.paginate(query, attrs)
    end

    test "handle default \'offset\' on query parameters" do
      query = from(u in User)
      attrs = %{}

      # Check response
      assert %{query: %{offset: 0}} = Helper.paginate(query, attrs)
    end

    test "handle valid \'offset\' on query parameters" do
      query = from(u in User)
      attrs = %{"offset" => "12500"}

      # Check response
      assert %{query: %{offset: 12_500}} = Helper.paginate(query, attrs)
    end

    test "handle invalid \'offset\' on query parameters" do
      query = from(u in User)
      attrs = %{"offset" => "invalid-offset"}

      # Check response
      assert %{query: %{offset: 0}} = Helper.paginate(query, attrs)
    end

    test "handle min \'offset\' on query parameters" do
      query = from(u in User)
      attrs = %{"offset" => "-1"}

      # Check response
      assert %{query: %{offset: 0}} = Helper.paginate(query, attrs)
    end

    test "handle default \'field\' on query parameters" do
      query = from(u in User)
      attrs = %{}

      # Check response
      assert %{query: %{field: :inserted_at}} = Helper.paginate(query, attrs)
    end

    test "handle valid \'field\' on query parameters" do
      query = from(u in User)
      attrs = %{"field" => "id"}

      # Check response
      assert %{query: %{field: :id}} = Helper.paginate(query, attrs)
    end

    test "handle invalid \'field\' on query parameters" do
      query = from(u in User)
      attrs = %{"field" => "invalid-field"}

      # Check response
      assert %{query: %{field: :inserted_at}} = Helper.paginate(query, attrs)
    end

    test "handle default \'order\' on query parameters" do
      query = from(u in User)
      attrs = %{}

      # Check response
      assert %{query: %{order: :asc}} = Helper.paginate(query, attrs)
    end

    test "handle ascendant \'order\' on query parameters" do
      query = from(u in User)
      attrs = %{"order" => "asc"}

      # Check response
      assert %{query: %{order: :asc}} = Helper.paginate(query, attrs)
    end

    test "handle descendant \'order\' on query parameters" do
      query = from(u in User)
      attrs = %{"order" => "desc"}

      # Check response
      assert %{query: %{order: :desc}} = Helper.paginate(query, attrs)
    end

    test "handle invalid \'order\' on query parameters" do
      query = from(u in User)
      attrs = %{"order" => "invalid-order"}

      # Check response
      assert %{query: %{order: :asc}} = Helper.paginate(query, attrs)
    end

    test "return a limited paginated list", %{
      pagination_records: %{
        user_01: user_01,
        user_02: user_02,
        user_03: user_03,
        user_04: user_04,
        user_05: user_05
      }
    } do
      query = from(u in User)
      attrs = %{"limit" => "5"}

      # Check response
      assert %{
        records: [
          record_01,
          record_02,
          record_03,
          record_04,
          record_05
        ],
        count: 5,
        page: 1,
        total_count: 10,
        total_pages: 2,
        query: %{
          limit: 5
        },
      } = Helper.paginate(query, attrs)
      # Check returned records
      assert record_01.id == user_01.id
      assert record_02.id == user_02.id
      assert record_03.id == user_03.id
      assert record_04.id == user_04.id
      assert record_05.id == user_05.id
    end

    test "return a paginated list with offset", %{
      pagination_records: %{
        user_06: user_06,
        user_07: user_07,
        user_08: user_08,
        user_09: user_09,
        user_10: user_10
      }
    } do
      query = from(u in User)
      attrs = %{"limit" => "5", "offset" => "1"}

      # Check response
      assert %{
        records: [
          record_01,
          record_02,
          record_03,
          record_04,
          record_05
        ],
        count: 5,
        page: 2,
        total_count: 10,
        total_pages: 2,
        query: %{limit: 5, offset: 1},
      } = Helper.paginate(query, attrs)
      # Check returned records
      assert record_01.id == user_06.id
      assert record_02.id == user_07.id
      assert record_03.id == user_08.id
      assert record_04.id == user_09.id
      assert record_05.id == user_10.id
    end

    test "return empty paginated list when offset is beyond the existing records" do
      query = from(u in User)
      attrs = %{"limit" => "5", "offset" => "2"}

      # Check response
      assert %{
        records: [],
        count: 0,
        page: 3,
        total_count: 10,
        total_pages: 2,
        query: %{limit: 5, offset: 2},
      } = Helper.paginate(query, attrs)
    end

    test "return a paginated list with specific field ascendant order", %{
      pagination_records: %{
        # Ordered by name (user_04 -> "Alice Anderson" -> _user_A)
        user_04: _user_A,
        user_03: _user_B,
        user_06: _user_C,
        user_01: _user_D,
        user_07: _user_E,
        user_05: user_F,
        user_08: user_G,
        user_10: user_H,
        user_09: user_I,
        user_02: user_J
      }
    } do
      query = from(u in User)
      attrs = %{
        "limit" => "5",
        "offset" => "1",
        "field" => "name",
        "order" => "asc"
      }

      # Check response
      assert %{
        records: [
          record_01,
          record_02,
          record_03,
          record_04,
          record_05
        ],
        count: 5,
        page: 2,
        total_count: 10,
        total_pages: 2,
        query: %{
          limit: 5
        },
      } = Helper.paginate(query, attrs)
      # Check returned records
      assert record_01.id == user_F.id
      assert record_02.id == user_G.id
      assert record_03.id == user_H.id
      assert record_04.id == user_I.id
      assert record_05.id == user_J.id
    end

    test "return a paginated list with specific field descendant order", %{
      pagination_records: %{
        # Ordered by name (user_04 -> "Alice Anderson")
        user_04: user_A,
        user_03: user_B,
        user_06: user_C,
        user_01: user_D,
        user_07: user_E,
        user_05: _user_F,
        user_08: _user_G,
        user_10: _user_H,
        user_09: _user_I,
        user_02: _user_J
      }
    } do
      query = from(u in User)
      attrs = %{
        "limit" => "5",
        "offset" => "1",
        "field" => "name",
        "order" => "desc"
      }

      # Check response
      assert %{
        records: [
          record_01,
          record_02,
          record_03,
          record_04,
          record_05
        ],
        count: 5,
        page: 2,
        total_count: 10,
        total_pages: 2,
        query: %{
          limit: 5
        },
      } = Helper.paginate(query, attrs)
      # Check returned records
      assert record_01.id == user_E.id
      assert record_02.id == user_D.id
      assert record_03.id == user_C.id
      assert record_04.id == user_B.id
      assert record_05.id == user_A.id
    end
  end

  # Returns boolean traversing the changset errors.
  describe "errors_on?/1" do
    test "true when error(s) exists" do
      changeset = %Changeset{errors: [field: ["some error"]]}

      # Check response
      assert Helper.errors_on?(changeset) == true
    end

    test "true when error(s) exists in embebed schemas" do
      changeset = %Changeset{
        errors: [],
        types: %{
          embedded_schema: {:assoc, %Ecto.Association.Has{cardinality: :many}}
        },
        changes: %{
          embedded_schema: [
            %Changeset{errors: [field: ["some embedded error"]]}
          ]
        }
      }

      # Check response
      assert Helper.errors_on?(changeset) == true
    end

    test "false when no errors exists" do
      changeset = %Changeset{errors: [], valid?: true}

      # Check response
      assert Helper.errors_on?(changeset) == false
    end
  end

  # Returns boolean traversing for specific changset errors.
  describe "errors_on?/2" do
    test "true when specific error(s) exists" do
      changeset = %Changeset{errors: [field: ["some error"]]}

      # Check response
      assert Helper.errors_on?(changeset, :field) == true
      assert Helper.errors_on?(changeset, :other_field) == false
    end

    test "true when specific error(s) exists in embebed schemas" do
      changeset = %Changeset{
        errors: [],
        types: %{
          embedded_schema: {:assoc, %Ecto.Association.Has{cardinality: :many}}
        },
        changes: %{
          embedded_schema: [
            %Changeset{errors: [field: ["some embedded error"]]}
          ]
        }
      }

      # Check response
      assert Helper.errors_on?(changeset, :embedded_schema) == true
      assert Helper.errors_on?(changeset, :other_field) == false
    end

    test "false when no specific errors exists" do
      changeset = %Changeset{errors: [field: ["other error"]]}

      # Check response
      assert Helper.errors_on?(changeset, :other_field) == false
    end
  end
end
