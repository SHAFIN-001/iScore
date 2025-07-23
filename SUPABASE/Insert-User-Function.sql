
-- Create function to insert user information bypassing schema cache issues
CREATE OR REPLACE FUNCTION insert_user_info(user_data JSONB)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    -- Check if user already exists
    IF EXISTS (SELECT 1 FROM user_information WHERE user_id = (user_data->>'user_id')::UUID) THEN
        result := jsonb_build_object(
            'success', false, 
            'error', 'User already exists',
            'error_code', 'USER_EXISTS'
        );
        RETURN result;
    END IF;

    -- Insert user information directly using user_id
    INSERT INTO user_information (
        user_id, username, email, phone, full_name, nick_name, 
        role, dob, gender, district, city, bio, bkash_number, profile_picture
    ) VALUES (
        (user_data->>'user_id')::UUID,
        user_data->>'username',
        user_data->>'email',
        user_data->>'phone',
        user_data->>'full_name',
        user_data->>'nick_name',
        user_data->>'role',
        (user_data->>'dob')::DATE,
        user_data->>'gender',
        user_data->>'district',
        user_data->>'city',
        user_data->>'bio',
        user_data->>'bkash_number',
        user_data->>'profile_picture'
    );
    
    -- Return success
    result := jsonb_build_object('success', true, 'message', 'User inserted successfully');
    RETURN result;
    
EXCEPTION 
    WHEN unique_violation THEN
        result := jsonb_build_object(
            'success', false, 
            'error', 'User already exists',
            'error_code', 'DUPLICATE_USER'
        );
        RETURN result;
    WHEN OTHERS THEN
        -- Return error details
        result := jsonb_build_object(
            'success', false, 
            'error', SQLERRM,
            'error_code', SQLSTATE
        );
        RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION insert_user_info(JSONB) TO anon;
GRANT EXECUTE ON FUNCTION insert_user_info(JSONB) TO authenticated;
