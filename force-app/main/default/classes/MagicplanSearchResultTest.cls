@IsTest
private class MagicplanSearchResultTest {

    @IsTest
    static void fromRow_remote_maps_all_fields() {
        MagicplanSearchRemoteProjects.Row r = new MagicplanSearchRemoteProjects.Row();
        r.id='p-1'; r.name='House'; r.address='12 Elm'; r.city='Boise'; r.state='ID'; r.zip='83702'; r.country='US';

        MagicplanSearchResult dto = MagicplanSearchResult.fromRow(r);
        System.assertEquals('p-1', dto.id);
        System.assertEquals('House', dto.name);
        System.assertEquals('12 Elm', dto.address);
        System.assertEquals('Boise', dto.city);
        System.assertEquals('ID', dto.state);
        System.assertEquals('83702', dto.zip);
        System.assertEquals('US', dto.country);
    }

    @IsTest
    static void fromRow_local_maps_all_fields() {
        MagicplanSearchLocalProjects.Row r = new MagicplanSearchLocalProjects.Row();
        r.id='p-2'; r.name='Garage'; r.address=null; r.city=null; r.state=null; r.zip=null; r.country=null;

        MagicplanSearchResult dto = MagicplanSearchResult.fromRow(r);
        System.assertEquals('p-2', dto.id);
        System.assertEquals('Garage', dto.name);
        System.assertEquals(null, dto.address);
    }

    @IsTest
    static void fromMap_maps_flat_and_nested() {
        Map<String,Object> nested = new Map<String,Object>{
            'address_1' => '77 Maple',
            'city' => 'Austin',
            'state' => 'TX',
            'zip' => '78701',
            'country' => 'US'
        };
        Map<String,Object> raw = new Map<String,Object>{
            'id' => 'p-3',
            'project_name' => 'Maple Addition',
            'address' => nested
        };

        MagicplanSearchResult dto = MagicplanSearchResult.fromMap(raw);
        System.assertEquals('p-3', dto.id);
        System.assertEquals('Maple Addition', dto.name);
        System.assertEquals('77 Maple', dto.address);
        System.assertEquals('Austin', dto.city);
        System.assertEquals('TX', dto.state);
        System.assertEquals('78701', dto.zip);
        System.assertEquals('US', dto.country);
    }
}
