# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"
require_module_spec_helper

RSpec.describe BasicData::Documents::TypeSeeder do
  include_context "with basic seed data", edition: "standard"

  subject(:seeder) { described_class.new(seed_data) }

  let(:seed_data) { basic_seed_data.merge(Source::SeedData.new(data_hash)) }

  let(:data_hash) do
    YAML.load <<~SEEDING_DATA_YAML
      document_types:
        - reference: doc_type_note
          name: Note
          is_default: true
        - reference: doc_type_idea
          name: Idea
          is_default: false
        - reference: doc_type_proposal
          name: Proposal
          is_default: false
    SEEDING_DATA_YAML
  end

  before do
    DocumentType.destroy_all
  end

  describe "#seed!" do
    context "when there are 3 or fewer document types" do
      before do
        create(:document_type, name: "Existing Type 1")
        create(:document_type, name: "Existing Type 2")
      end

      it "seeds additional types from seed data" do
        expect { seeder.seed! }
          .to change(DocumentType, :count)
          .by(3)

        aggregate_failures "creates types with correct attributes from seed data" do
          seeded_document_types = ["Note", "Idea", "Proposal"]

          expect(DocumentType.pluck(:name)).to contain_exactly(
            "Existing type 1",
            "Existing type 2",
            *seeded_document_types
          )
        end
      end

      context "when no default type exists and there is a defaultable type" do
        it "sets the first type as default" do
          expect(DocumentType.where(is_default: true).count).to eq(0)
          seeder.seed!

          default_types = DocumentType.where(is_default: true)
          expect(default_types.count).to eq(1)
          expect(default_types.first.name).to eq("Note")
        end
      end

      context "when a default type already exists" do
        before do
          create(:document_type, name: "Custom Default", is_default: true)
        end

        it "does not override the existing default" do
          expect(DocumentType.where(is_default: true).count).to eq(1)
          seeder.seed!

          default_types = DocumentType.where(is_default: true)
          expect(default_types.count).to eq(1)
          expect(default_types.first.name).to eq("Custom default")
        end
      end
    end

    context "when there are more than 3 document types" do
      before do
        create_list(:document_type, 3)
        create(:document_type, name: "Type 4", is_default: true)
      end

      it "does not seed additional types" do
        expect { seeder.seed! }
          .not_to change(DocumentType, :count)

        aggregate_failures "does not modify existing types" do
          expect(DocumentType.count).to eq(4)
          expect(DocumentType.find_by(name: "Type 4", is_default: true)).to be_present
        end
      end
    end

    context "when no document types exist" do
      it "seeds all types from seed data" do
        expect { seeder.seed! }
          .to change(DocumentType, :count)
          .from(0).to(3)
      end

      it "sets the correct default type" do
        seeder.seed!

        default_type = DocumentType.find_by(is_default: true)
        expect(default_type.name).to eq("Note")
      end
    end

    context "with duplicate type names in seed data and database" do
      before do
        create(:document_type, name: "Note", is_default: false)
      end

      it "does not create duplicate types" do
        seeder.seed!

        expect(DocumentType.where(name: "Note").count).to eq(1)
        note_type = DocumentType.find_by(name: "Note")
        expect(note_type.is_default).to be(false)
      end
    end
  end
end
